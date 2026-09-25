"""Tests des routes admin OCR — POST /process et GET /status.

Le DB est mocké via override FastAPI (voir conftest.py).
ARQ est mocké pour éviter Redis.
Les modèles SQLAlchemy sont simulés avec SimpleNamespace.
"""

from __future__ import annotations

import io
import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import AsyncClient

from app.models.college import CollegeStatus
from tests.fakes.fake_arq import override_arq


def make_college(college_id: uuid.UUID | None = None):
    return types.SimpleNamespace(
        id=college_id or uuid.uuid4(),
        user_id=uuid.uuid4(),
        college_ref_id=1,
        status=CollegeStatus.pending,
        reload_count=0,
        ocr_page_progress=0,
        total_pages=None,
    )


def make_job(college_id: uuid.UUID, job_id: uuid.UUID | None = None, status: str = "pending"):
    return types.SimpleNamespace(
        id=job_id or uuid.uuid4(),
        college_id=college_id,
        user_id=uuid.uuid4(),
        status=status,
        arq_job_id=None,
    )


ADMIN_AUTH = ("admin", "testpass")
WRONG_AUTH = ("admin", "wrongpass")


class TestBasicAuth:
    async def test_401_without_credentials(self, client: AsyncClient):
        college_id = str(uuid.uuid4())
        resp = await client.get(f"/v1/admin/colleges/{college_id}/status")
        assert resp.status_code == 401

    async def test_401_with_wrong_credentials(self, client: AsyncClient):
        college_id = str(uuid.uuid4())
        resp = await client.get(
            f"/v1/admin/colleges/{college_id}/status",
            auth=WRONG_AUTH,
        )
        assert resp.status_code == 401

    async def test_200_with_valid_credentials(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id)
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))

        resp = await client.get(
            f"/v1/admin/colleges/{college_id}/status",
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 200


class TestGetCollegeStatus:
    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        college_id = str(uuid.uuid4())

        resp = await client.get(
            f"/v1/admin/colleges/{college_id}/status",
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 404
        body = resp.json()
        assert body["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_returns_data_wrapper(self, client: AsyncClient, mock_db):
        """AC#4 — la réponse est { 'data': { 'status': ..., 'ocr_page_progress': ..., 'total_pages': ... } }"""
        college_id = uuid.uuid4()
        college = make_college(college_id)
        college.status = CollegeStatus.processing
        college.ocr_page_progress = 47
        college.total_pages = 380

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))

        resp = await client.get(
            f"/v1/admin/colleges/{college_id}/status",
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "data" in body
        data = body["data"]
        assert data["status"] == "processing"
        assert data["ocr_page_progress"] == 47
        assert data["total_pages"] == 380

    async def test_includes_job_id_when_job_exists(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id)
        job = make_job(college_id)

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=job)))

        resp = await client.get(
            f"/v1/admin/colleges/{college_id}/status",
            auth=ADMIN_AUTH,
        )
        body = resp.json()
        assert body["data"]["job_id"] == str(job.id)

    async def test_job_id_none_when_no_job(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id)

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))

        resp = await client.get(
            f"/v1/admin/colleges/{college_id}/status",
            auth=ADMIN_AUTH,
        )
        body = resp.json()
        assert body["data"]["job_id"] is None


class TestProcessCollege:
    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        college_id = str(uuid.uuid4())

        resp = await client.post(
            f"/v1/admin/colleges/{college_id}/process",
            auth=ADMIN_AUTH,
            files={"pdf": ("test.pdf", io.BytesIO(b"%PDF-1.4 minimal"), "application/pdf")},
        )
        assert resp.status_code == 404
        body = resp.json()
        assert body["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_409_when_job_already_processing(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id)
        existing_job = make_job(college_id, status="processing")

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=existing_job)))

        resp = await client.post(
            f"/v1/admin/colleges/{college_id}/process",
            auth=ADMIN_AUTH,
            files={"pdf": ("test.pdf", io.BytesIO(b"%PDF-1.4"), "application/pdf")},
        )
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "JOB_IN_PROGRESS"

    async def test_creates_job_and_returns_pending(self, client: AsyncClient, mock_db, tmp_path):
        """AC#1 — POST /process crée un GenerationJob avec statut 'pending'."""
        college_id = uuid.uuid4()
        college = make_college(college_id)

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()

        # Simuler refresh() pour setter job.status
        async def fake_refresh(obj):
            if not hasattr(obj, "status"):
                obj.status = "pending"

        mock_db.refresh = AsyncMock(side_effect=fake_refresh)

        # Mock ARQ pool
        mock_pool = AsyncMock()
        mock_arq_job = MagicMock()
        mock_arq_job.job_id = "arq-test-id"
        mock_pool.enqueue_job = AsyncMock(return_value=mock_arq_job)
        override_arq(mock_pool)

        with patch("app.services.imports.settings") as mock_settings:
            mock_settings.pdf_storage_path = str(tmp_path)
            mock_settings.admin_username = "admin"
            mock_settings.admin_password = "testpass"

            resp = await client.post(
                f"/v1/admin/colleges/{college_id}/process",
                auth=ADMIN_AUTH,
                files={"pdf": ("test.pdf", io.BytesIO(b"%PDF-1.4 content"), "application/pdf")},
            )

        assert resp.status_code == 202
        body = resp.json()
        assert "data" in body
        assert "job_id" in body["data"]
        assert body["data"]["status"] == "pending"
