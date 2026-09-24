"""Tests GET /v1/admin/colleges/{id}/stats — statistiques fiches + pertinence (Story 1.4/1.5)."""

from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from tests.factories import make_card, make_item, make_user
from tests.factories import make_college as make_pg_college

ADMIN_AUTH = ("admin", "testpass")


def make_college(college_id=None):
    return types.SimpleNamespace(id=college_id or uuid.uuid4())


def make_job(college_id=None, hash_shared=False):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        status="generation_complete",
        hash_shared=hash_shared,
    )


def stats_side_effects(card_rows=None, item_rows=None, job=None, fb_rows=None):
    """Construit les 4 side_effects pour get_college_stats.

    Ordre des appels DB :
      1. card counts par rang → .all()
      2. items OCR → .all()
      3. dernier job generation_complete → .scalar_one_or_none()
      4. avis des fiches (flash_cards.user_feedback) par rang → .all()
    """
    return [
        MagicMock(all=MagicMock(return_value=card_rows or [])),
        MagicMock(all=MagicMock(return_value=item_rows or [])),
        MagicMock(scalar_one_or_none=MagicMock(return_value=job)),
        MagicMock(all=MagicMock(return_value=fb_rows or [])),
    ]


class TestGetCollegeStats:
    async def test_401_without_credentials(self, client: AsyncClient):
        college_id = str(uuid.uuid4())
        resp = await client.get(f"/v1/admin/colleges/{college_id}/stats")
        assert resp.status_code == 401

    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        college_id = str(uuid.uuid4())
        resp = await client.get(f"/v1/admin/colleges/{college_id}/stats", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_stats_empty_college(self, client: AsyncClient, mock_db):
        """Collège sans fiches ni items — valeurs à zéro, pertinence_stats null."""
        college_id = uuid.uuid4()
        college = make_college(college_id)
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(side_effect=stats_side_effects())

        resp = await client.get(f"/v1/admin/colleges/{college_id}/stats", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()["data"]
        assert body["card_count_by_rang"] == {"A": 0, "B": 0, "C": 0}
        assert body["avg_ocr_confidence"] is None
        assert body["items_ocr_confidence"] == []
        assert body["hash_shared"] is False
        assert body["pertinence_stats"] is None

    async def test_stats_with_cards(self, client: AsyncClient, mock_db):
        """Collège avec fiches A/B et items OCR."""
        college_id = uuid.uuid4()
        college = make_college(college_id)
        mock_db.get = AsyncMock(return_value=college)

        item_rows = [(1, 0.9, False), (2, 0.6, True)]
        mock_db.execute = AsyncMock(
            side_effect=stats_side_effects(
                card_rows=[("A", 3), ("B", 2)],
                item_rows=item_rows,
            )
        )

        resp = await client.get(f"/v1/admin/colleges/{college_id}/stats", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()["data"]
        assert body["card_count_by_rang"] == {"A": 3, "B": 2, "C": 0}
        assert abs(body["avg_ocr_confidence"] - 0.75) < 0.01
        assert len(body["items_ocr_confidence"]) == 2
        assert body["items_ocr_confidence"][0]["item_number"] == 1
        assert body["items_ocr_confidence"][1]["low_confidence"] is True

    async def test_stats_hash_shared_true(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id)
        job = make_job(college_id=college_id, hash_shared=True)
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(side_effect=stats_side_effects(job=job))

        resp = await client.get(f"/v1/admin/colleges/{college_id}/stats", auth=ADMIN_AUTH)
        assert resp.json()["data"]["hash_shared"] is True

    async def test_stats_pertinence_null_when_no_feedback(self, client: AsyncClient, mock_db):
        """pertinence_stats est null quand aucun feedback n'existe."""
        college_id = uuid.uuid4()
        college = make_college(college_id)
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(side_effect=stats_side_effects(fb_rows=[]))

        resp = await client.get(f"/v1/admin/colleges/{college_id}/stats", auth=ADMIN_AUTH)
        assert resp.json()["data"]["pertinence_stats"] is None

    async def test_response_has_data_wrapper(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id)
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(side_effect=stats_side_effects())
        resp = await client.get(f"/v1/admin/colleges/{college_id}/stats", auth=ADMIN_AUTH)
        assert "data" in resp.json()


@pytest.mark.pg
class TestCollegeStatsPertinence:
    """pertinence_stats calculé depuis flash_cards.user_feedback (chantier 5 R3), sur Postgres réel."""

    async def test_stats_with_pertinence(self, pg_client, pg_factory):
        async with pg_factory() as db:
            college = await make_pg_college(db, await make_user(db))
            item_a = await make_item(db, college, 1, rang="A")
            item_b = await make_item(db, college, 2, rang="B")
            await make_card(db, item_a, user_feedback="positive")
            await make_card(db, item_a, user_feedback="positive")
            await make_card(db, item_b, user_feedback="negative")
            await make_card(db, item_b)  # sans avis : non comptée
            await db.commit()

        resp = await pg_client.get(f"/v1/admin/colleges/{college.id}/stats", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        ps = resp.json()["data"]["pertinence_stats"]
        assert ps is not None
        assert ps["global_pertinent"] == 2
        assert ps["global_not_pertinent"] == 1
        assert ps["total_evaluated"] == 3
        assert ps["by_rang"]["A"]["pertinent"] == 2
        assert ps["by_rang"]["B"]["not_pertinent"] == 1
        assert ps["by_rang"]["C"] == {"pertinent": 0, "not_pertinent": 0}

    async def test_stats_pertinence_null_without_feedback(self, pg_client, pg_factory):
        async with pg_factory() as db:
            college = await make_pg_college(db, await make_user(db))
            await make_card(db, await make_item(db, college, 1))
            await db.commit()

        resp = await pg_client.get(f"/v1/admin/colleges/{college.id}/stats", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        assert resp.json()["data"]["pertinence_stats"] is None
