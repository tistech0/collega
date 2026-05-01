"""Tests du worker cleanup ARQ — suppression ocr_text après 24h."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.workers.cleanup_worker import cleanup_ocr_text


class TestCleanupWorker:
    async def test_cleans_ocr_text_from_old_jobs(self):
        """AC#4 — supprime ocr_text des items liés à des jobs > 24h."""
        mock_result = MagicMock(rowcount=5)
        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.execute = AsyncMock(return_value=mock_result)
        mock_db.commit = AsyncMock()

        with patch("app.workers.cleanup_worker.async_session_factory", return_value=mock_db):
            await cleanup_ocr_text({})

        mock_db.execute.assert_called_once()
        mock_db.commit.assert_called_once()

    async def test_logs_cleaned_count(self, caplog):
        """AC#4 — logue le nombre d'items nettoyés."""
        import logging
        mock_result = MagicMock(rowcount=3)
        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.execute = AsyncMock(return_value=mock_result)
        mock_db.commit = AsyncMock()

        with patch("app.workers.cleanup_worker.async_session_factory", return_value=mock_db):
            with caplog.at_level(logging.INFO, logger="app.workers.cleanup_worker"):
                await cleanup_ocr_text({})

        assert "3" in caplog.text

    async def test_zero_items_cleaned_when_no_old_jobs(self):
        """AC#4 — 0 items si aucun job > 24h."""
        mock_result = MagicMock(rowcount=0)
        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.execute = AsyncMock(return_value=mock_result)
        mock_db.commit = AsyncMock()

        with patch("app.workers.cleanup_worker.async_session_factory", return_value=mock_db):
            await cleanup_ocr_text({})

        mock_db.commit.assert_called_once()
