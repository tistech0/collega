"""Partie B — GET /v1/colleges/{id}/pdf : le PDF de SON collège, reprise par Range."""

import uuid
from unittest.mock import AsyncMock

from httpx import AsyncClient

from app.deps import get_current_user
from app.services.imports import CurrentPdf
from tests.api.test_colleges import _make_college, _make_user

PDF = b"%PDF-1.7\n" + b"x" * 1000


def _install(monkeypatch, found):
    from app.api.v1.colleges import pdf as pdf_module

    async def fake_current_pdfs(db, ids):
        return found

    monkeypatch.setattr(pdf_module.import_service, "current_pdfs", fake_current_pdfs)


class TestCollegePdf:
    async def test_sans_jeton_401(self, client: AsyncClient):
        resp = await client.get(f"/v1/colleges/{uuid.uuid4()}/pdf")
        assert resp.status_code == 401

    async def test_proprietaire_recoit_le_pdf(self, client: AsyncClient, mock_db, monkeypatch, tmp_path):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=26, user_id=user.id)
        path = tmp_path / "c.pdf"
        path.write_bytes(PDF)
        _install(monkeypatch, {college.id: CurrentPdf(job_id=uuid.uuid4(), path=path, size=len(PDF))})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        assert resp.headers["content-type"] == "application/pdf"
        assert resp.headers["accept-ranges"] == "bytes"
        assert resp.content == PDF

    async def test_reprise_par_range_206(self, client: AsyncClient, mock_db, monkeypatch, tmp_path):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=26, user_id=user.id)
        path = tmp_path / "c.pdf"
        path.write_bytes(PDF)
        _install(monkeypatch, {college.id: CurrentPdf(job_id=uuid.uuid4(), path=path, size=len(PDF))})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/pdf", headers={"Range": "bytes=0-3"})
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 206
        assert resp.content == b"%PDF"

    async def test_college_d_un_autre_compte_404_sans_fuite(self, client: AsyncClient, mock_db, monkeypatch):
        from app.main import app

        user = _make_user()
        other = _make_college(college_ref_id=26)  # autre propriétaire
        _install(monkeypatch, {})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=other)
        try:
            resp = await client.get(f"/v1/colleges/{other.id}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_college_inconnu_404(self, client: AsyncClient, mock_db, monkeypatch):
        from app.main import app

        user = _make_user()
        _install(monkeypatch, {})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=None)
        try:
            resp = await client.get(f"/v1/colleges/{uuid.uuid4()}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_aucun_pdf_en_service_404_pdf_not_found(self, client: AsyncClient, mock_db, monkeypatch):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=26, user_id=user.id)
        _install(monkeypatch, {})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "PDF_NOT_FOUND"
