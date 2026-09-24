"""Tests GET /v1/admin/colleges/{id}/feedback — feedback testeuse joint fiche (Story 7.8 AC3)."""

from __future__ import annotations

import types
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def make_college(college_id=None):
    return types.SimpleNamespace(id=college_id or uuid.uuid4())


def make_feedback(is_pertinent=True, tester_id="testeuse"):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        flash_card_id=uuid.uuid4(),
        tester_id=tester_id,
        is_pertinent=is_pertinent,
        created_at=datetime.now(UTC),
    )


def _rows_result(rows):
    return MagicMock(all=MagicMock(return_value=rows))


class TestGetCollegeFeedback:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get(f"/v1/admin/colleges/{uuid.uuid4()}/feedback")
        assert resp.status_code == 401

    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.get(f"/v1/admin/colleges/{uuid.uuid4()}/feedback", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_returns_feedback_joined_to_card(self, client: AsyncClient, mock_db):
        college = make_college()
        mock_db.get = AsyncMock(return_value=college)
        fb_np = make_feedback(is_pertinent=False, tester_id="testeuse")
        fb_p = make_feedback(is_pertinent=True, tester_id="testeuse")
        # rows : (TesterFeedback, recto, verso, card_type, rang)
        rows = [
            (fb_np, "Question peu claire ?", "Réponse", "classique", "A"),
            (fb_p, "Bonne question ?", "Bonne réponse", "definition", "B"),
        ]
        mock_db.execute = AsyncMock(return_value=_rows_result(rows))

        resp = await client.get(f"/v1/admin/colleges/{college.id}/feedback", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 2
        data = body["data"]
        # Le feedback non pertinent (signal qualité n°1) est exposé avec sa fiche
        assert data[0]["is_pertinent"] is False
        assert data[0]["recto"] == "Question peu claire ?"
        assert data[0]["card_type"] == "classique"
        assert data[0]["rang"] == "A"
        assert data[0]["tester_id"] == "testeuse"
        assert data[0]["flash_card_id"] == str(fb_np.flash_card_id)
        assert data[1]["is_pertinent"] is True

    async def test_empty_returns_empty_list(self, client: AsyncClient, mock_db):
        college = make_college()
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=_rows_result([]))

        resp = await client.get(f"/v1/admin/colleges/{college.id}/feedback", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"data": [], "total": 0}
