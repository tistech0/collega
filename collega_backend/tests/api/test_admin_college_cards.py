"""Tests GET /v1/admin/colleges/{id}/cards — inspection fiches générées (Story 7.8 AC2)."""

from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def make_college(college_id=None):
    return types.SimpleNamespace(id=college_id or uuid.uuid4())


def make_card(card_type="classique", rang="A", recto="Q?", verso="R", score=0.9, low=False):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        card_type=card_type,
        rang=rang,
        recto=recto,
        verso=verso,
        ocr_confidence_score=score,
        low_confidence=low,
    )


def _rows_result(rows):
    return MagicMock(all=MagicMock(return_value=rows))


class TestGetCollegeCards:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get(f"/v1/admin/colleges/{uuid.uuid4()}/cards")
        assert resp.status_code == 401

    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.get(f"/v1/admin/colleges/{uuid.uuid4()}/cards", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_returns_cards_with_item_number(self, client: AsyncClient, mock_db):
        college = make_college()
        mock_db.get = AsyncMock(return_value=college)
        rows = [
            (make_card(card_type="classique", rang="A", recto="Q1", verso="R1", score=0.92), 1),
            (make_card(card_type="definition", rang="B", recto="Terme", verso="Def", score=0.4, low=True), 2),
        ]
        mock_db.execute = AsyncMock(return_value=_rows_result(rows))

        resp = await client.get(f"/v1/admin/colleges/{college.id}/cards", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 2
        data = body["data"]
        assert data[0]["item_number"] == 1
        assert data[0]["card_type"] == "classique"
        assert data[0]["recto"] == "Q1"
        assert data[0]["verso"] == "R1"
        assert data[1]["item_number"] == 2
        assert data[1]["rang"] == "B"
        assert data[1]["low_confidence"] is True

    async def test_empty_college_returns_empty_list(self, client: AsyncClient, mock_db):
        college = make_college()
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=_rows_result([]))

        resp = await client.get(f"/v1/admin/colleges/{college.id}/cards", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"data": [], "total": 0}
