"""Tests POST /v1/tester/flash-cards/{id}/feedback — enregistrement et UPSERT du feedback."""
from __future__ import annotations

import types
import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

TESTER_AUTH = ("tester", "testpass")


def make_flash_card(card_id=None, college_id=None):
    return types.SimpleNamespace(
        id=card_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        item_id=uuid.uuid4(),
        rang="A",
        card_type="classique",
        recto="Question ?",
        verso="Réponse.",
        low_confidence=False,
        ocr_confidence_score=0.85,
    )


def make_feedback(card_id=None, college_id=None, is_pertinent=True):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        flash_card_id=card_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        tester_id="tester",
        is_pertinent=is_pertinent,
        created_at=datetime.now(timezone.utc),
    )


class TestSubmitFeedback:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.post(
            f"/v1/tester/flash-cards/{uuid.uuid4()}/feedback",
            json={"is_pertinent": True},
        )
        assert resp.status_code == 401

    async def test_404_for_unknown_card(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.post(
            f"/v1/tester/flash-cards/{uuid.uuid4()}/feedback",
            json={"is_pertinent": True},
            auth=TESTER_AUTH,
        )
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "CARD_NOT_FOUND"

    async def test_creates_new_feedback(self, client: AsyncClient, mock_db):
        card_id = uuid.uuid4()
        college_id = uuid.uuid4()
        card = make_flash_card(card_id=card_id, college_id=college_id)
        feedback = make_feedback(card_id=card_id, college_id=college_id, is_pertinent=True)

        mock_db.get = AsyncMock(return_value=card)
        # SELECT existing feedback → None
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )
        # db.refresh side_effect : simule le rechargement du feedback
        async def fake_refresh(obj):
            obj.id = feedback.id
            obj.created_at = feedback.created_at

        mock_db.refresh = AsyncMock(side_effect=fake_refresh)

        resp = await client.post(
            f"/v1/tester/flash-cards/{card_id}/feedback",
            json={"is_pertinent": True},
            auth=TESTER_AUTH,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["is_pertinent"] is True
        assert data["tester_id"] == "tester"
        assert data["card_id"] == str(card_id)
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()

    async def test_upsert_updates_existing_feedback(self, client: AsyncClient, mock_db):
        """Si un feedback existe déjà, il est mis à jour (UPSERT)."""
        card_id = uuid.uuid4()
        college_id = uuid.uuid4()
        card = make_flash_card(card_id=card_id, college_id=college_id)
        existing = make_feedback(card_id=card_id, college_id=college_id, is_pertinent=False)

        mock_db.get = AsyncMock(return_value=card)
        # SELECT existing feedback → retourne un feedback existant
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=existing))
        )
        mock_db.refresh = AsyncMock()

        resp = await client.post(
            f"/v1/tester/flash-cards/{card_id}/feedback",
            json={"is_pertinent": True},  # on inverse
            auth=TESTER_AUTH,
        )
        assert resp.status_code == 200
        # db.add ne doit PAS avoir été appelé (c'est un UPDATE)
        mock_db.add.assert_not_called()
        mock_db.commit.assert_called_once()
        # is_pertinent a bien été mis à jour sur l'objet existant
        assert existing.is_pertinent is True

    async def test_feedback_not_pertinent(self, client: AsyncClient, mock_db):
        card_id = uuid.uuid4()
        card = make_flash_card(card_id=card_id)
        feedback = make_feedback(card_id=card_id, is_pertinent=False)

        mock_db.get = AsyncMock(return_value=card)
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )

        async def fake_refresh(obj):
            obj.id = feedback.id
            obj.created_at = feedback.created_at

        mock_db.refresh = AsyncMock(side_effect=fake_refresh)

        resp = await client.post(
            f"/v1/tester/flash-cards/{card_id}/feedback",
            json={"is_pertinent": False},
            auth=TESTER_AUTH,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["is_pertinent"] is False

    async def test_response_has_data_wrapper(self, client: AsyncClient, mock_db):
        card_id = uuid.uuid4()
        card = make_flash_card(card_id=card_id)
        feedback = make_feedback(card_id=card_id)

        mock_db.get = AsyncMock(return_value=card)
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )

        async def fake_refresh(obj):
            obj.id = feedback.id
            obj.created_at = feedback.created_at

        mock_db.refresh = AsyncMock(side_effect=fake_refresh)

        resp = await client.post(
            f"/v1/tester/flash-cards/{card_id}/feedback",
            json={"is_pertinent": True},
            auth=TESTER_AUTH,
        )
        assert "data" in resp.json()
        assert "feedback_id" in resp.json()["data"]
