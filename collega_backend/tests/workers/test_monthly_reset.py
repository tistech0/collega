"""Tests cron `reset_monthly_reloads` — Story 7.2 AC #2."""
from __future__ import annotations

import logging
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


class TestResetMonthlyReloads:
    async def test_reset_monthly_reloads_appelle_un_seul_update(self):
        """Un seul UPDATE batch met à zéro les compteurs des users échus."""
        from app.workers.cleanup_worker import reset_monthly_reloads

        mock_result = MagicMock(rowcount=4)
        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.execute = AsyncMock(return_value=mock_result)
        mock_db.commit = AsyncMock()

        with patch(
            "app.workers.cleanup_worker.async_session_factory",
            return_value=mock_db,
        ):
            await reset_monthly_reloads({})

        # Un seul UPDATE batch
        assert mock_db.execute.await_count == 1
        mock_db.commit.assert_awaited_once()

    async def test_reset_logge_le_nombre_de_users(self, caplog):
        """Logue le rowcount pour traçabilité ARQ."""
        from app.workers.cleanup_worker import reset_monthly_reloads

        mock_result = MagicMock(rowcount=7)
        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.execute = AsyncMock(return_value=mock_result)
        mock_db.commit = AsyncMock()

        with patch(
            "app.workers.cleanup_worker.async_session_factory",
            return_value=mock_db,
        ):
            with caplog.at_level(logging.INFO, logger="app.workers.cleanup_worker"):
                await reset_monthly_reloads({})

        assert "7" in caplog.text

    async def test_reset_zero_si_aucun_user_echu(self):
        """rowcount=0 → log normal, commit quand même appelé (idempotent)."""
        from app.workers.cleanup_worker import reset_monthly_reloads

        mock_result = MagicMock(rowcount=0)
        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.execute = AsyncMock(return_value=mock_result)
        mock_db.commit = AsyncMock()

        with patch(
            "app.workers.cleanup_worker.async_session_factory",
            return_value=mock_db,
        ):
            await reset_monthly_reloads({})

        mock_db.commit.assert_awaited_once()


class TestCronSettings:
    """Vérifie que le cron est bien enregistré dans WORKER_SETTINGS."""

    def test_reset_monthly_reloads_dans_cron_jobs(self):
        from app.workers import settings as worker_settings

        cron_jobs = worker_settings.WORKER_SETTINGS["cron_jobs"]
        # cron_jobs est une liste d'instances CronJob d'ARQ — on cherche par .coroutine
        names = [getattr(j, "coroutine", None).__name__ for j in cron_jobs if getattr(j, "coroutine", None)]
        assert "reset_monthly_reloads" in names
