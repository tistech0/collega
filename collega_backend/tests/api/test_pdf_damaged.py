"""422 PDF_DAMAGED : un PDF qui ne s'ouvre pas est refusé à la réception (chantier 1)."""
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.services.ocr.pdf_check import assert_pdf_readable
from tests.api_pg import login_as, pg_client  # noqa: F401
from tests.factories import make_college, make_user
from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401

SAMPLE_PDF = Path(__file__).parents[1] / "fixtures" / "sample_ecni.pdf"
# Magic bytes valides mais structure illisible (comme ANAPATH 4e.pdf : index de fin
# qui pointe au milieu des données).
DAMAGED_PDF = b"%PDF-1.6\n" + b"\x8f\x12garbage" * 50 + b"\nstartxref\n12345\n%%EOF\n"


async def test_readable_pdf_returns_page_count(tmp_path):
    assert await assert_pdf_readable(SAMPLE_PDF) == 1


async def test_damaged_pdf_raises_422(tmp_path):
    path = tmp_path / "x.pdf"
    path.write_bytes(DAMAGED_PDF)
    with pytest.raises(Exception) as exc:
        await assert_pdf_readable(path)
    assert exc.value.status_code == 422 and exc.value.detail["code"] == "PDF_DAMAGED"


@pytest.mark.pg
async def test_damaged_reimport_rejected_without_quota_or_job(pg_client, pg_factory, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete", reload_count=0)
        await db.commit()
    login_as(user)

    response = await pg_client.post(
        f"/v1/colleges/{college.college_ref_id}/import",
        files={"pdf": ("anapath.pdf", DAMAGED_PDF, "application/pdf")},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "PDF_DAMAGED"
    async with pg_factory() as s:
        assert (await s.get(College, college.id)).reload_count == 0
        assert (await s.execute(select(func.count()).select_from(GenerationJob))).scalar_one() == 0
    assert list(tmp_path.glob("*.pdf")) == []
