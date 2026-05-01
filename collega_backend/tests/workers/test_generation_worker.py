"""Tests du worker génération ARQ — statuts, flux ocr_complete → generation_complete."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.workers.generation_worker import generate_college_cards


def make_job(status: str = "ocr_complete"):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        college_id=uuid.uuid4(),
        status=status,
        user_id=uuid.uuid4(),
        pdf_hash=None,
        hash_shared=False,
        card_count=0,
        error_message=None,
    )


class TestGenerationWorker:
    async def test_ocr_complete_transitions_to_generation_complete(self):
        """AC#1 — job ocr_complete → generation_complete après succès."""
        job = make_job(status="ocr_complete")
        college_id = str(uuid.uuid4())
        job_id = str(job.id)

        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.get = AsyncMock(return_value=job)

        expected_result = {"college_id": college_id, "job_id": job_id, "hash_shared": False, "card_count": 3}

        with patch("app.workers.generation_worker.async_session_factory", return_value=mock_db):
            with patch("app.workers.generation_worker.CardGenerator") as mock_gen_cls:
                mock_gen = AsyncMock()
                mock_gen.generate_for_college = AsyncMock(return_value=expected_result)
                mock_gen_cls.return_value = mock_gen

                result = await generate_college_cards({}, college_id, job_id, "/fake/path.pdf")

        assert result["card_count"] == 3
        mock_gen.generate_for_college.assert_called_once()

    async def test_invalid_job_state_returns_error(self):
        """AC#1 — job non-ocr_complete → retourne error sans appel CardGenerator."""
        job = make_job(status="pending")

        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.get = AsyncMock(return_value=job)

        with patch("app.workers.generation_worker.async_session_factory", return_value=mock_db):
            with patch("app.workers.generation_worker.CardGenerator") as mock_gen_cls:
                result = await generate_college_cards({}, str(uuid.uuid4()), str(job.id), "/fake/path.pdf")

        assert result.get("error") == "invalid_job_state"
        mock_gen_cls.assert_not_called()

    async def test_job_not_found_returns_error(self):
        """AC#1 — job inexistant → retourne error."""
        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.get = AsyncMock(return_value=None)

        with patch("app.workers.generation_worker.async_session_factory", return_value=mock_db):
            result = await generate_college_cards({}, str(uuid.uuid4()), str(uuid.uuid4()), "/fake/path.pdf")

        assert result.get("error") == "invalid_job_state"

    async def test_exception_marks_job_failed_and_reraises(self):
        """AC#3 — exception Claude → rollback, job.status = failed, re-raise."""
        job = make_job(status="ocr_complete")

        mock_db = AsyncMock()
        mock_db.__aenter__ = AsyncMock(return_value=mock_db)
        mock_db.__aexit__ = AsyncMock(return_value=False)
        mock_db.get = AsyncMock(return_value=job)
        mock_db.rollback = AsyncMock()
        mock_db.commit = AsyncMock()

        with patch("app.workers.generation_worker.async_session_factory", return_value=mock_db):
            with patch("app.workers.generation_worker.CardGenerator") as mock_gen_cls:
                mock_gen = AsyncMock()
                mock_gen.generate_for_college = AsyncMock(side_effect=RuntimeError("Claude API down"))
                mock_gen_cls.return_value = mock_gen

                with pytest.raises(RuntimeError, match="Claude API down"):
                    await generate_college_cards({}, str(uuid.uuid4()), str(job.id), "/fake/path.pdf")

        mock_db.rollback.assert_called_once()
        assert job.status == "failed"
        assert "Claude API down" in job.error_message
        mock_db.commit.assert_called()
