"""Tests GET /v1/admin/usage — agrégat tokens + coût € global/par user (Story 7.8 AC4)."""

from __future__ import annotations

import uuid
from unittest.mock import AsyncMock, MagicMock

from httpx import AsyncClient

from app.services.generation.token_cost import compute_cost_eur

ADMIN_AUTH = ("admin", "testpass")


def _global_result(g_input, g_output):
    return MagicMock(one=MagicMock(return_value=(g_input, g_output)))


def _by_user_result(rows):
    return MagicMock(all=MagicMock(return_value=rows))


class TestGetUsage:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get("/v1/admin/usage")
        assert resp.status_code == 401

    async def test_global_and_per_user_aggregate(self, client: AsyncClient, mock_db):
        u1, u2 = uuid.uuid4(), uuid.uuid4()
        # by_user : (user_id, email, input_tokens, output_tokens)
        by_user_rows = [
            (u1, "a@example.com", 300_000, 100_000),
            (u2, "b@example.com", 200_000, 100_000),
        ]
        mock_db.execute = AsyncMock(
            side_effect=[
                _global_result(500_000, 200_000),
                _by_user_result(by_user_rows),
            ]
        )

        resp = await client.get("/v1/admin/usage", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]

        # Global
        assert data["input_tokens"] == 500_000
        assert data["output_tokens"] == 200_000
        assert data["cost_eur"] == compute_cost_eur(500_000, 200_000)

        # Par user
        assert len(data["by_user"]) == 2
        assert data["by_user"][0]["email"] == "a@example.com"
        assert data["by_user"][0]["input_tokens"] == 300_000
        assert data["by_user"][0]["cost_eur"] == compute_cost_eur(300_000, 100_000)
        assert data["by_user"][1]["user_id"] == str(u2)

    async def test_null_jobs_counted_as_zero(self, client: AsyncClient, mock_db):
        """Aucun usage mesuré (coalesce → 0) → totaux et coût à 0."""
        mock_db.execute = AsyncMock(
            side_effect=[
                _global_result(0, 0),
                _by_user_result([]),
            ]
        )

        resp = await client.get("/v1/admin/usage", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["input_tokens"] == 0
        assert data["output_tokens"] == 0
        assert data["cost_eur"] == 0.0
        assert data["by_user"] == []
