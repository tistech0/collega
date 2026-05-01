"""Tests GET /v1/tester/colleges/{id}/items — items et fiches du collège."""
from __future__ import annotations

import types
import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

TESTER_AUTH = ("tester", "testpass")


def make_college(college_id=None):
    return types.SimpleNamespace(id=college_id or uuid.uuid4(), college_ref_id=3)


def make_item(item_id=None, college_id=None, item_number=1, rang="A"):
    return types.SimpleNamespace(
        id=item_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        item_number=item_number,
        rang=rang,
        chapter_title="Chapitre Test",
    )


def make_card(card_id=None, item_id=None, college_id=None, rang="A"):
    return types.SimpleNamespace(
        id=card_id or uuid.uuid4(),
        item_id=item_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        card_type="classique",
        rang=rang,
        recto="Question ?",
        verso="Réponse.",
        low_confidence=False,
        ocr_confidence_score=0.85,
        created_at=datetime.now(timezone.utc),
    )


def make_feedback(card_id=None, is_pertinent=True):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        flash_card_id=card_id or uuid.uuid4(),
        is_pertinent=is_pertinent,
        tester_id="tester",
        created_at=datetime.now(timezone.utc),
    )


class TestGetCollegeItems:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get(f"/v1/tester/colleges/{uuid.uuid4()}/items")
        assert resp.status_code == 401

    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.get(
            f"/v1/tester/colleges/{uuid.uuid4()}/items", auth=TESTER_AUTH
        )
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_returns_items_with_cards(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        item = make_item(college_id=college_id, item_number=1, rang="A")
        card = make_card(college_id=college_id, item_id=item.id)
        mock_db.get = AsyncMock(return_value=college)

        # execute calls :
        # 1. SELECT Item where college_id → [item]
        # 2. SELECT FlashCard, TesterFeedback LEFT JOIN where item_id → [(card, None)]
        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[item])))),
            MagicMock(all=MagicMock(return_value=[(card, None)])),
        ])

        resp = await client.get(
            f"/v1/tester/colleges/{college_id}/items", auth=TESTER_AUTH
        )
        assert resp.status_code == 200
        body = resp.json()["data"]
        assert body["college_id"] == str(college_id)
        assert len(body["items"]) == 1
        assert body["items"][0]["item_number"] == 1
        assert body["items"][0]["rang"] == "A"
        assert len(body["items"][0]["flash_cards"]) == 1
        assert body["items"][0]["flash_cards"][0]["feedback"] is None

    async def test_returns_existing_feedback(self, client: AsyncClient, mock_db):
        """Une fiche déjà évaluée retourne le feedback dans la réponse."""
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        item = make_item(college_id=college_id)
        card_id = uuid.uuid4()
        card = make_card(card_id=card_id, college_id=college_id, item_id=item.id)
        feedback = make_feedback(card_id=card_id, is_pertinent=True)
        mock_db.get = AsyncMock(return_value=college)

        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[item])))),
            MagicMock(all=MagicMock(return_value=[(card, feedback)])),
        ])

        resp = await client.get(
            f"/v1/tester/colleges/{college_id}/items", auth=TESTER_AUTH
        )
        assert resp.status_code == 200
        fb = resp.json()["data"]["items"][0]["flash_cards"][0]["feedback"]
        assert fb is not None
        assert fb["is_pertinent"] is True
        assert fb["tester_id"] == "tester"

    async def test_low_confidence_flag_propagated(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        item = make_item(college_id=college_id)
        card = make_card(college_id=college_id, item_id=item.id)
        card.low_confidence = True
        card.ocr_confidence_score = 0.55
        mock_db.get = AsyncMock(return_value=college)

        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[item])))),
            MagicMock(all=MagicMock(return_value=[(card, None)])),
        ])

        resp = await client.get(
            f"/v1/tester/colleges/{college_id}/items", auth=TESTER_AUTH
        )
        card_data = resp.json()["data"]["items"][0]["flash_cards"][0]
        assert card_data["low_confidence"] is True
        assert card_data["ocr_confidence_score"] == 0.55

    async def test_empty_college_no_items(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        mock_db.get = AsyncMock(return_value=college)
        # SELECT Item → vide
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[]))))
        )

        resp = await client.get(
            f"/v1/tester/colleges/{college_id}/items", auth=TESTER_AUTH
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["items"] == []
