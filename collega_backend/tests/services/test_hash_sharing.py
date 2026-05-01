"""Tests du service SimilarityChecker — hash SHA-256 et find_similar_job."""
from __future__ import annotations

import io
import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.generation.hash_sharing import SHA256SimilarityChecker


class TestSHA256SimilarityCheckerComputeHash:
    def test_deterministic_on_same_content(self):
        """AC#2 — même contenu → même hash (déterministe)."""
        checker = SHA256SimilarityChecker()
        content = b"fake pdf content for test"

        with patch("builtins.open", return_value=io.BytesIO(content)):
            h1 = checker.compute_hash("/fake/path1.pdf")

        with patch("builtins.open", return_value=io.BytesIO(content)):
            h2 = checker.compute_hash("/fake/path2.pdf")

        assert h1 == h2
        assert len(h1) == 64  # SHA-256 hex = 64 chars

    def test_different_content_different_hash(self):
        """AC#2 — contenu différent → hash différent."""
        checker = SHA256SimilarityChecker()

        with patch("builtins.open", return_value=io.BytesIO(b"content A")):
            h1 = checker.compute_hash("/fake/a.pdf")

        with patch("builtins.open", return_value=io.BytesIO(b"content B")):
            h2 = checker.compute_hash("/fake/b.pdf")

        assert h1 != h2


class TestSHA256SimilarityCheckerFindSimilarJob:
    async def test_returns_matching_job(self):
        """AC#2 — retourne un job generation_complete avec le même hash."""
        checker = SHA256SimilarityChecker()
        pdf_hash = "abc123" * 10 + "abcd"  # 64 chars

        mock_job = types.SimpleNamespace(id=uuid.uuid4(), status="generation_complete", pdf_hash=pdf_hash)
        mock_scalar = MagicMock(scalar_one_or_none=MagicMock(return_value=mock_job))
        db = AsyncMock()
        db.execute = AsyncMock(return_value=mock_scalar)

        result = await checker.find_similar_job(db, pdf_hash)
        assert result is mock_job

    async def test_returns_none_when_no_match(self):
        """AC#2 — retourne None si aucun job ne correspond."""
        checker = SHA256SimilarityChecker()

        mock_scalar = MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        db = AsyncMock()
        db.execute = AsyncMock(return_value=mock_scalar)

        result = await checker.find_similar_job(db, "nonexistent_hash")
        assert result is None
