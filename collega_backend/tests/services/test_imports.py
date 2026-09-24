"""Service d'import partagé (chantier 5, § 2) : contrôle du PDF reçu et création du job."""

from __future__ import annotations

import io
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException, UploadFile
from sqlalchemy import func, select
from starlette.datastructures import Headers

from app.models.generation_job import GenerationJob
from app.services import imports
from tests.factories import make_college, make_user


def _upload(content: bytes, *, filename: str = "cours.pdf", content_type: str = "application/pdf") -> UploadFile:
    return UploadFile(file=io.BytesIO(content), filename=filename, headers=Headers({"content-type": content_type}))


class TestSaveUpload:
    async def test_pdf_valide_ecrit_integralement(self, tmp_path):
        dest = tmp_path / "a.pdf"
        content = b"%PDF-1.4 " + b"x" * (3 * 1024 * 1024)
        await imports.save_upload(_upload(content), dest, max_size=None)
        assert dest.read_bytes() == content

    async def test_magic_invalide_422_et_aucun_fichier(self, tmp_path):
        dest = tmp_path / "a.pdf"
        with pytest.raises(HTTPException) as exc:
            await imports.save_upload(_upload(b"PK\x03\x04 pas un pdf"), dest, max_size=None)
        assert exc.value.status_code == 422
        assert exc.value.detail["code"] == "INVALID_FILE_TYPE"
        assert not dest.exists()

    async def test_type_invalide_422(self, tmp_path):
        dest = tmp_path / "a.pdf"
        with pytest.raises(HTTPException) as exc:
            await imports.save_upload(
                _upload(b"%PDF-1.4", filename="a.txt", content_type="text/plain"), dest, max_size=None
            )
        assert exc.value.status_code == 422
        assert exc.value.detail["code"] == "INVALID_FILE_TYPE"
        assert not dest.exists()

    async def test_taille_depassee_413_et_fichier_supprime(self, tmp_path):
        dest = tmp_path / "a.pdf"
        content = b"%PDF-1.4 " + b"x" * (3 * 1024 * 1024)
        with pytest.raises(HTTPException) as exc:
            await imports.save_upload(_upload(content), dest, max_size=2 * 1024 * 1024)
        assert exc.value.status_code == 413
        assert exc.value.detail["code"] == "FILE_TOO_LARGE"
        assert not dest.exists()


class TestCreateJobAndEnqueue:
    async def test_enqueue_ok_renseigne_arq_job_id(self, sqlite_session, tmp_path):
        user = await make_user(sqlite_session)
        college = await make_college(sqlite_session, user)
        pdf = tmp_path / "a.pdf"
        pdf.write_bytes(b"%PDF-1.4")
        arq = MagicMock()
        arq.enqueue_job = AsyncMock(return_value=MagicMock(job_id="arq-1"))
        job_id = uuid.uuid4()

        job = await imports.create_job_and_enqueue(
            sqlite_session, arq, college=college, user_id=user.id, job_id=job_id, pdf_path=pdf
        )

        assert (job.id, job.status, job.arq_job_id) == (job_id, "pending", "arq-1")
        arq.enqueue_job.assert_awaited_once_with("process_college_ocr", str(college.id), str(job_id), str(pdf))
        assert pdf.exists()

    async def test_echec_enqueue_supprime_job_et_pdf_503(self, sqlite_session, tmp_path):
        user = await make_user(sqlite_session)
        college = await make_college(sqlite_session, user)
        pdf = tmp_path / "a.pdf"
        pdf.write_bytes(b"%PDF-1.4")
        arq = MagicMock()
        arq.enqueue_job = AsyncMock(side_effect=ConnectionError("redis down"))

        with pytest.raises(HTTPException) as exc:
            await imports.create_job_and_enqueue(
                sqlite_session, arq, college=college, user_id=user.id, job_id=uuid.uuid4(), pdf_path=pdf
            )

        assert exc.value.status_code == 503
        assert exc.value.detail["code"] == "QUEUE_UNAVAILABLE"
        assert not pdf.exists()
        count = (await sqlite_session.execute(select(func.count()).select_from(GenerationJob))).scalar_one()
        assert count == 0


class TestAssertNoActiveJob:
    async def test_job_actif_409(self, sqlite_session):
        user = await make_user(sqlite_session)
        college = await make_college(sqlite_session, user)
        sqlite_session.add(GenerationJob(college_id=college.id, user_id=user.id, status="ocr_complete"))
        await sqlite_session.flush()
        with pytest.raises(HTTPException) as exc:
            await imports.assert_no_active_job(sqlite_session, college)
        assert (exc.value.status_code, exc.value.detail["code"]) == (409, "JOB_IN_PROGRESS")

    async def test_job_termine_ok(self, sqlite_session):
        user = await make_user(sqlite_session)
        college = await make_college(sqlite_session, user)
        sqlite_session.add(GenerationJob(college_id=college.id, user_id=user.id, status="generation_complete"))
        await sqlite_session.flush()
        await imports.assert_no_active_job(sqlite_session, college)


def test_validate_ref_id():
    imports.validate_ref_id(1)
    imports.validate_ref_id(39)
    for bad in (0, 40):
        with pytest.raises(HTTPException) as exc:
            imports.validate_ref_id(bad)
        assert exc.value.detail["code"] == "INVALID_REF_ID"
