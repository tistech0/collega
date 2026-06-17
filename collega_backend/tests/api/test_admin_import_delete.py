"""Tests DELETE /v1/admin/colleges/{college_id} — Story 7.7 AC #4."""
from __future__ import annotations

import types
import uuid
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def make_college(college_id=None):
    return types.SimpleNamespace(id=college_id or uuid.uuid4(), college_ref_id=12)


class TestDeleteImport:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.delete(f"/v1/admin/colleges/{uuid.uuid4()}")
        assert resp.status_code == 401

    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.delete(f"/v1/admin/colleges/{uuid.uuid4()}", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_deletes_college_and_cleans_pdfs(self, client: AsyncClient, mock_db, monkeypatch):
        college = make_college()
        mock_db.get = AsyncMock(return_value=college)
        mock_db.delete = AsyncMock()
        mock_db.commit = AsyncMock()

        # PDF cleanup monkeypatché : glob renvoie 2 fichiers, on vérifie unlink tenté
        fake_pdf1 = MagicMock()
        fake_pdf2 = MagicMock()
        glob_calls = []

        def fake_glob(self, pattern):
            glob_calls.append(pattern)
            return [fake_pdf1, fake_pdf2]

        monkeypatch.setattr(Path, "glob", fake_glob)

        resp = await client.delete(f"/v1/admin/colleges/{college.id}", auth=ADMIN_AUTH)
        assert resp.status_code == 204

        # College supprimé + commit
        mock_db.delete.assert_awaited_once_with(college)
        mock_db.commit.assert_awaited_once()

        # PDF cleanup tenté pour ce college (pattern {college_id}_*.pdf)
        assert glob_calls == [f"{college.id}_*.pdf"]
        fake_pdf1.unlink.assert_called_once_with(missing_ok=True)
        fake_pdf2.unlink.assert_called_once_with(missing_ok=True)

    async def test_409_when_active_job_exists(self, client: AsyncClient, mock_db):
        """review 7.7 D3 — refuse la suppression si un job est encore actif."""
        college = make_college()
        mock_db.get = AsyncMock(return_value=college)
        mock_db.delete = AsyncMock()
        # Le garde-fou interroge GenerationJob actif → renvoyer un job (≠ None)
        active_job = types.SimpleNamespace(id=uuid.uuid4(), status="processing")
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=active_job))
        )

        resp = await client.delete(f"/v1/admin/colleges/{college.id}", auth=ADMIN_AUTH)
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "JOB_ACTIVE"
        # Aucune suppression ne doit avoir lieu tant qu'un job tourne
        mock_db.delete.assert_not_awaited()

    async def test_pdf_cleanup_failure_does_not_break_delete(self, client: AsyncClient, mock_db, monkeypatch):
        college = make_college()
        mock_db.get = AsyncMock(return_value=college)
        mock_db.delete = AsyncMock()
        mock_db.commit = AsyncMock()

        def boom(self, pattern):
            raise OSError("disk gone")

        monkeypatch.setattr(Path, "glob", boom)

        resp = await client.delete(f"/v1/admin/colleges/{college.id}", auth=ADMIN_AUTH)
        # La suppression DB reste un succès même si le cleanup disque échoue
        assert resp.status_code == 204
        mock_db.delete.assert_awaited_once_with(college)
