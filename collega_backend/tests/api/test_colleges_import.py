"""Tests POST /v1/colleges/{ref_id}/import, GET /v1/colleges/{college_id}/status."""
from __future__ import annotations

import types
import uuid
from io import BytesIO
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import AsyncClient

from app.deps import get_current_user, require_subscription


def _make_user(user_id=None, is_subscribed=True, is_beta=False):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="test@example.com",
        is_subscribed=is_subscribed,
        is_beta=is_beta,
    )


def _make_college(ref_id: int, college_id=None, user_id=None, status="pending"):
    cid = college_id or uuid.uuid4()
    return types.SimpleNamespace(
        id=cid,
        user_id=user_id or uuid.uuid4(),
        college_ref_id=ref_id,
        status=status,
        ocr_page_progress=0,
        total_pages=None,
    )


def _make_job(college_id, job_id=None, status="pending"):
    return types.SimpleNamespace(
        id=job_id or uuid.uuid4(),
        college_id=college_id,
        status=status,
        arq_job_id=None,
    )


_PDF_BYTES = b"%PDF-1.4 fake pdf content for testing"


@pytest.fixture(autouse=True)
def _readable_pdf(monkeypatch):
    """L'écriture du PDF est simulée ici : l'ouverture réelle (422 PDF_DAMAGED) est
    testée dans test_pdf_damaged.py."""
    from unittest.mock import AsyncMock

    from app.api.v1 import colleges as colleges_module

    monkeypatch.setattr(colleges_module, "assert_pdf_readable", AsyncMock(return_value=1))


class TestImportCollegePdf:
    async def test_ref_id_invalide_retourne_422(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        app.dependency_overrides[require_subscription] = lambda: user

        for bad_ref_id in [0, 40]:
            resp = await client.post(
                f"/v1/colleges/{bad_ref_id}/import",
                files={"pdf": ("test.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )
            assert resp.status_code == 422, f"Expected 422 for ref_id={bad_ref_id}"
            assert resp.json()["detail"]["code"] == "INVALID_REF_ID"

        app.dependency_overrides.pop(require_subscription, None)

    async def test_non_authentifie_retourne_401(self, client: AsyncClient):
        resp = await client.post(
            "/v1/colleges/15/import",
            files={"pdf": ("test.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
        )
        assert resp.status_code == 401

    async def test_sans_abonnement_retourne_403(self, client: AsyncClient):
        from app.main import app

        user = _make_user(is_subscribed=False, is_beta=False)
        app.dependency_overrides[get_current_user] = lambda: user
        app.dependency_overrides.pop(require_subscription, None)

        resp = await client.post(
            "/v1/colleges/15/import",
            files={"pdf": ("test.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
        )
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 403
        assert resp.json()["detail"]["code"] == "SUBSCRIPTION_REQUIRED"

    async def test_fichier_non_pdf_retourne_422(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.post(
            "/v1/colleges/15/import",
            files={"pdf": ("test.txt", BytesIO(b"not a pdf"), "text/plain")},
        )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 422
        assert resp.json()["detail"]["code"] == "INVALID_FILE_TYPE"

    async def test_magic_bytes_invalides_retourne_422(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.post(
            "/v1/colleges/15/import",
            files={"pdf": ("test.pdf", BytesIO(b"not a pdf at all"), "application/pdf")},
        )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 422
        assert resp.json()["detail"]["code"] == "INVALID_FILE_TYPE"

    async def test_import_ok_retourne_202(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        app.dependency_overrides[require_subscription] = lambda: user

        # execute: 1) aucun college existant, 2) aucun job actif
        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
            ]
        )
        mock_db.flush = AsyncMock()

        # add() capture le college créé pour lui donner un id fixe
        added_objects: list = []
        def mock_add(obj):
            added_objects.append(obj)
            if hasattr(obj, "college_ref_id") and not getattr(obj, "id", None):
                obj.id = uuid.uuid4()
                obj.user_id = user.id
        mock_db.add = mock_add

        async def mock_refresh(obj):
            if hasattr(obj, "arq_job_id") and not getattr(obj, "id", None):
                obj.id = uuid.uuid4()
        mock_db.refresh = mock_refresh

        mock_arq_job = MagicMock()
        mock_arq_job.job_id = "arq-job-123"
        mock_pool = AsyncMock()
        mock_pool.enqueue_job = AsyncMock(return_value=mock_arq_job)
        mock_pool.close = AsyncMock()

        with (
            patch("app.api.v1.colleges.Path.mkdir"),
            patch("builtins.open", MagicMock()),
            patch("arq.create_pool", AsyncMock(return_value=mock_pool)),
        ):
            resp = await client.post(
                "/v1/colleges/15/import",
                files={"pdf": ("neurologie.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )

        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 202
        data = resp.json()["data"]
        assert "college_id" in data
        assert "job_id" in data
        assert data["status"] == "pending"

    async def test_job_actif_retourne_409(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        college = _make_college(ref_id=15, user_id=user.id)
        existing_job = _make_job(college.id, status="processing")
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),  # college existant
                MagicMock(scalar_one_or_none=MagicMock(return_value=existing_job)),  # job actif
            ]
        )

        resp = await client.post(
            "/v1/colleges/15/import",
            files={"pdf": ("test.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
        )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "JOB_IN_PROGRESS"


class TestGetCollegeStatus:
    async def test_ownership_check_retourne_404_si_autre_user(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        other_user_id = uuid.uuid4()
        college = _make_college(ref_id=15, user_id=other_user_id)
        college_id = college.id
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.get = AsyncMock(return_value=college)

        resp = await client.get(f"/v1/colleges/{college_id}/status")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_status_ok_retourne_progress_et_ref_id(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        college = _make_college(ref_id=15, user_id=user.id, status="processing")
        college.ocr_page_progress = 42
        college.total_pages = 380
        job = _make_job(college.id, status="processing")
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=job))
        )

        resp = await client.get(f"/v1/colleges/{college.id}/status")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["ref_id"] == 15
        assert data["status"] == "processing"
        assert data["ocr_page_progress"] == 42
        assert data["total_pages"] == 380
        assert data["job_id"] is not None
