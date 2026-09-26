"""Partie B — PDF en service d'un collège : dernier import publié dont le fichier existe."""

import uuid
from unittest.mock import AsyncMock, MagicMock

from app.core.config import settings
from app.services import imports as import_service


def _rows(rows):
    return MagicMock(all=MagicMock(return_value=rows))


async def test_liste_vide_ne_touche_pas_la_base():
    db = MagicMock(execute=AsyncMock())
    assert await import_service.current_pdfs(db, []) == {}
    db.execute.assert_not_called()


async def test_retourne_le_pdf_du_dernier_job_publie(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    college_id, job_id = uuid.uuid4(), uuid.uuid4()
    (tmp_path / f"{college_id}_{job_id}.pdf").write_bytes(b"%PDF-1.7 abc")
    db = MagicMock(execute=AsyncMock(return_value=_rows([(college_id, job_id)])))

    found = await import_service.current_pdfs(db, [college_id])

    assert found[college_id].job_id == job_id
    assert found[college_id].size == len(b"%PDF-1.7 abc")
    assert found[college_id].path == tmp_path / f"{college_id}_{job_id}.pdf"


async def test_fichier_absent_collège_ignore(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    college_id, job_id = uuid.uuid4(), uuid.uuid4()
    db = MagicMock(execute=AsyncMock(return_value=_rows([(college_id, job_id)])))

    assert await import_service.current_pdfs(db, [college_id]) == {}
