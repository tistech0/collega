"""POST /v1/admin/jobs/{id}/stop (story 7.7, chantier 1) sur Postgres réel."""

import uuid
from unittest.mock import AsyncMock

import pytest
from sqlalchemy import func, select

from app.models.college import College
from app.models.content import JobItem
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_card, make_college, make_draft, make_item, make_job, make_user

pytestmark = pytest.mark.pg


async def _seed(pg_factory, *, college_status="generation_complete", job_status="ocr_complete", arq_job_id="arq-1"):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status=college_status)
        if college_status == "generation_complete":
            item = await make_item(db, college, 304, text="contenu en service")
            await make_card(db, item)
        job = await make_job(db, college, status=job_status)
        job.arq_job_id = arq_job_id
        await make_draft(db, job, 304, "nouveau texte")
        await db.commit()
    return college, job


async def test_401_without_credentials(pg_client):
    assert (await pg_client.post(f"/v1/admin/jobs/{uuid.uuid4()}/stop")).status_code == 401


async def test_404_for_unknown_job(pg_client):
    resp = await pg_client.post(f"/v1/admin/jobs/{uuid.uuid4()}/stop", auth=ADMIN_AUTH)
    assert resp.status_code == 404 and resp.json()["detail"]["code"] == "JOB_NOT_FOUND"


@pytest.mark.parametrize("status", ["generation_complete", "failed"])
async def test_409_when_job_not_active(pg_client, pg_factory, monkeypatch, status):
    abort = AsyncMock(return_value=True)
    monkeypatch.setattr("app.api.v1.admin.abort_arq_job", abort)
    _, job = await _seed(pg_factory, job_status=status)
    resp = await pg_client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
    assert resp.status_code == 409 and resp.json()["detail"]["code"] == "JOB_NOT_ACTIVE"
    abort.assert_not_awaited()


async def test_stop_reimport_keeps_content_and_clears_draft(pg_client, pg_factory, monkeypatch, fake_arq):
    abort = AsyncMock(return_value=True)
    monkeypatch.setattr("app.api.v1.admin.abort_arq_job", abort)
    college, job = await _seed(pg_factory)

    resp = await pg_client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)

    assert resp.status_code == 200
    assert resp.json()["data"] == {
        "job_id": str(job.id),
        "status": "failed",
        "error_message": "Annulé par l'admin",
        "aborted": True,
    }
    abort.assert_awaited_once_with(fake_arq, "arq-1")
    async with pg_factory() as s:
        assert (await s.get(College, college.id)).status == "generation_complete"
        assert (await s.execute(select(func.count()).select_from(FlashCard))).scalar_one() == 1
        assert (await s.execute(select(func.count()).select_from(JobItem))).scalar_one() == 0


async def test_stop_first_import_marks_college_failed(pg_client, pg_factory, monkeypatch):
    monkeypatch.setattr("app.api.v1.admin.abort_arq_job", AsyncMock(return_value=True))
    college, job = await _seed(pg_factory, college_status="ocr_complete")
    await pg_client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
    async with pg_factory() as s:
        assert (await s.get(College, college.id)).status == "failed"


async def test_forces_status_even_without_arq_job_id(pg_client, pg_factory, monkeypatch):
    abort = AsyncMock(return_value=True)
    monkeypatch.setattr("app.api.v1.admin.abort_arq_job", abort)
    _, job = await _seed(pg_factory, arq_job_id=None)
    resp = await pg_client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
    assert resp.json()["data"]["status"] == "failed" and resp.json()["data"]["aborted"] is False
    abort.assert_not_awaited()


async def test_aborted_false_when_abort_not_confirmed(pg_client, pg_factory, monkeypatch):
    monkeypatch.setattr("app.api.v1.admin.abort_arq_job", AsyncMock(return_value=False))
    _, job = await _seed(pg_factory)
    resp = await pg_client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
    assert resp.json()["data"]["aborted"] is False
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "failed"
