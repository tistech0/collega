"""Tests GET /v1/admin/overview (KPI accueil console) — Story 7.6 AC #4."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


class TestOverview:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get("/v1/admin/overview")
        assert resp.status_code == 401

    async def test_aggregates_users_and_jobs(self, client: AsyncClient, mock_db):
        # Mock indépendant de l'ordre des requêtes : chaque résultat sait
        # répondre à .scalar_one() (count users) ET .all() (group_by statuts),
        # donc un éventuel réordonnancement des db.execute ne fausse rien.
        result = MagicMock(
            scalar_one=MagicMock(return_value=5),
            all=MagicMock(return_value=[("failed", 2), ("generation_complete", 7)]),
        )
        mock_db.execute = AsyncMock(return_value=result)

        resp = await client.get("/v1/admin/overview", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]

        assert data["users_total"] == 5
        # Les 5 clés sont toujours présentes, 0 par défaut
        assert set(data["jobs_by_status"].keys()) == {
            "pending", "processing", "ocr_complete", "generation_complete", "failed",
        }
        assert data["jobs_by_status"]["failed"] == 2
        assert data["jobs_by_status"]["generation_complete"] == 7
        assert data["jobs_by_status"]["pending"] == 0
        assert data["jobs_failed"] == 2

    async def test_zero_state(self, client: AsyncClient, mock_db):
        result = MagicMock(
            scalar_one=MagicMock(return_value=0),
            all=MagicMock(return_value=[]),
        )
        mock_db.execute = AsyncMock(return_value=result)

        resp = await client.get("/v1/admin/overview", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["users_total"] == 0
        assert data["jobs_failed"] == 0
        assert all(v == 0 for v in data["jobs_by_status"].values())
