"""Tests GET /v1/colleges, GET /v1/colleges/{id}/items, GET /v1/colleges/{id}/items/{id}/cards."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from app.deps import get_current_user


def _make_user(user_id=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="test@example.com",
        is_subscribed=True,
        is_beta=False,
    )


def _make_college(college_ref_id: int, college_id=None, user_id=None, status="generation_complete"):
    college_id = college_id or uuid.uuid4()
    return types.SimpleNamespace(
        id=college_id,
        user_id=user_id or uuid.uuid4(),
        college_ref_id=college_ref_id,
        status=status,
    )


def _make_item(college_id, item_id=None, item_number=232, rang="A"):
    return types.SimpleNamespace(
        id=item_id or uuid.uuid4(),
        college_id=college_id,
        item_number=item_number,
        rang=rang,
        chapter_title="Insuffisance Cardiaque",
        ocr_confidence_score=0.9,
        low_confidence=False,
    )


def _make_card(item_id, college_id, user_id, card_id=None, rang="A", card_type="definition"):
    return types.SimpleNamespace(
        id=card_id or uuid.uuid4(),
        item_id=item_id,
        college_id=college_id,
        user_id=user_id,
        card_type=card_type,
        rang=rang,
        recto="Définition IC",
        verso="Incapacité du coeur à assurer le débit nécessaire.",
        ocr_confidence_score=0.9,
        low_confidence=False,
        user_feedback=None,
    )


class TestListUserColleges:
    async def test_non_authentifie_retourne_401(self, client: AsyncClient):
        """Sans token → 401."""
        resp = await client.get("/v1/colleges")
        assert resp.status_code == 401

    async def test_user_sans_import_retourne_liste_vide(self, client: AsyncClient, mock_db):
        """Utilisateur authentifié sans collège importé → liste vide."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        # SELECT College.where(user_id) → []
        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
            )
        )

        resp = await client.get("/v1/colleges")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 0
        assert body["data"] == []

    async def test_user_avec_un_college_retourne_une_entree(self, client: AsyncClient, mock_db):
        """Utilisateur avec 1 collège importé → 1 entrée avec college_ref_id, status et card counts."""
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=15, user_id=user.id)
        app.dependency_overrides[get_current_user] = lambda: user

        # Appels execute dans l'ordre :
        # 1. SELECT College.where(user_id) → [college]
        # 2. SELECT college_id, rang, count GROUP BY college_id, rang → [(college.id, "A", 5), ...]
        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(
                    scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[college])))
                ),
                MagicMock(all=MagicMock(return_value=[(college.id, "A", 5), (college.id, "B", 3)])),
            ]
        )

        resp = await client.get("/v1/colleges")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 1
        entry = body["data"][0]
        assert entry["college_ref_id"] == 15
        assert entry["status"] == "generation_complete"
        assert entry["card_count_a"] == 5
        assert entry["card_count_b"] == 3
        assert entry["card_count_c"] == 0

    async def test_response_a_wrapper_data_et_total(self, client: AsyncClient, mock_db):
        """La réponse respecte le format {data: [...], total: N}."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
            )
        )

        resp = await client.get("/v1/colleges")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        body = resp.json()
        assert "data" in body
        assert "total" in body


class TestListCollegeItems:
    async def test_non_authentifie_retourne_401(self, client: AsyncClient):
        """Sans token → 401."""
        college_id = uuid.uuid4()
        resp = await client.get(f"/v1/colleges/{college_id}/items")
        assert resp.status_code == 401

    async def test_college_autre_user_retourne_404(self, client: AsyncClient, mock_db):
        """College appartenant à un autre user → 404."""
        from app.main import app

        user = _make_user()
        other_user_id = uuid.uuid4()
        college = _make_college(college_ref_id=5, user_id=other_user_id)
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.get = AsyncMock(return_value=college)

        resp = await client.get(f"/v1/colleges/{college.id}/items")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_generation_non_complete_retourne_409(self, client: AsyncClient, mock_db):
        """College avec status != generation_complete → 409."""
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=5, user_id=user.id, status="processing")
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.get = AsyncMock(return_value=college)

        resp = await client.get(f"/v1/colleges/{college.id}/items")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "GENERATION_NOT_COMPLETE"

    async def test_liste_items_avec_card_counts_corrects(self, client: AsyncClient, mock_db):
        """College generation_complete → liste items avec card counts A/B/C."""
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=5, user_id=user.id)
        item = _make_item(college_id=college.id)
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[item])))),
                MagicMock(all=MagicMock(return_value=[(item.id, "A", 3), (item.id, "B", 2)])),
            ]
        )

        resp = await client.get(f"/v1/colleges/{college.id}/items")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 1
        entry = body["data"][0]
        assert entry["item_number"] == 232
        assert entry["rang"] == "A"
        assert entry["card_count_a"] == 3
        assert entry["card_count_b"] == 2
        assert entry["card_count_c"] == 0


class TestListItemCards:
    async def test_ownership_cards_autre_college_retourne_404(self, client: AsyncClient, mock_db):
        """Item appartenant à un autre college → 404."""
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=5, user_id=user.id)
        other_college_id = uuid.uuid4()
        item = _make_item(college_id=other_college_id)
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.get = AsyncMock(side_effect=[college, item])

        resp = await client.get(f"/v1/colleges/{college.id}/items/{item.id}/cards")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "ITEM_NOT_FOUND"

    async def test_liste_cards_triees_rang_puis_card_type(self, client: AsyncClient, mock_db):
        """Cards retournées triées rang ASC, card_type ASC."""
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=5, user_id=user.id)
        item = _make_item(college_id=college.id)
        card_a_classique = _make_card(item.id, college.id, user.id, rang="A", card_type="classique")
        card_a_def = _make_card(item.id, college.id, user.id, rang="A", card_type="definition")
        card_b = _make_card(item.id, college.id, user.id, rang="B", card_type="classique")
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.get = AsyncMock(side_effect=[college, item])
        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalars=MagicMock(
                    return_value=MagicMock(all=MagicMock(return_value=[card_a_classique, card_a_def, card_b]))
                )
            )
        )

        resp = await client.get(f"/v1/colleges/{college.id}/items/{item.id}/cards")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 3
        cards = body["data"]
        assert cards[0]["rang"] == "A"
        assert cards[0]["card_type"] == "classique"
        assert cards[1]["rang"] == "A"
        assert cards[1]["card_type"] == "definition"
        assert cards[2]["rang"] == "B"
