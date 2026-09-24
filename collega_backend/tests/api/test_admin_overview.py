"""Tests GET /v1/admin/overview (KPI accueil console) — Story 7.6 AC #4."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def _results(users_total, status_rows, usage_rows=()):
    """db.execute : 1) nombre d'utilisateurs, 2) jobs par statut, 3) coût 30 jours par modèle."""
    return [
        MagicMock(scalar_one=MagicMock(return_value=users_total)),
        MagicMock(all=MagicMock(return_value=status_rows)),
        MagicMock(all=MagicMock(return_value=list(usage_rows))),
    ]


class TestOverview:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get("/v1/admin/overview")
        assert resp.status_code == 401

    async def test_aggregates_users_and_jobs(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(
            side_effect=_results(5, [("failed", 2), ("generation_complete", 7)], [("claude-sonnet-4-6", 1_000_000, 0)])
        )

        resp = await client.get("/v1/admin/overview", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]

        assert data["users_total"] == 5
        # Les 5 clés sont toujours présentes, 0 par défaut
        assert set(data["jobs_by_status"].keys()) == {
            "pending",
            "processing",
            "ocr_complete",
            "generation_complete",
            "failed",
        }
        assert data["jobs_by_status"]["failed"] == 2
        assert data["jobs_by_status"]["generation_complete"] == 7
        assert data["jobs_by_status"]["pending"] == 0
        assert data["jobs_failed"] == 2
        assert data["cost_last_30_days_eur"] == 2.76  # 1M in Sonnet 4.6 = 3 USD × 0.92

    async def test_zero_state(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(side_effect=_results(0, []))

        resp = await client.get("/v1/admin/overview", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["users_total"] == 0
        assert data["jobs_failed"] == 0
        assert all(v == 0 for v in data["jobs_by_status"].values())
        assert data["cost_last_30_days_eur"] == 0.0
