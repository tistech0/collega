"""Tests POST /v1/admin/jobs/{job_id}/stop — Story 7.7 AC #3."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from app.models.generation_job_event import GenerationJobEvent

ADMIN_AUTH = ("admin", "testpass")


def make_job(status="processing", arq_job_id="arq-123"):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        college_id=uuid.uuid4(),
        status=status,
        arq_job_id=arq_job_id,
        error_message=None,
    )


class TestStopJob:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.post(f"/v1/admin/jobs/{uuid.uuid4()}/stop")
        assert resp.status_code == 401

    async def test_404_for_unknown_job(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.post(f"/v1/admin/jobs/{uuid.uuid4()}/stop", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "JOB_NOT_FOUND"

    async def test_409_when_job_not_active(self, client: AsyncClient, mock_db, monkeypatch):
        abort_mock = AsyncMock(return_value=True)
        monkeypatch.setattr("app.api.v1.admin.abort_arq_job", abort_mock)
        job = make_job(status="generation_complete")
        mock_db.get = AsyncMock(return_value=job)

        resp = await client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "JOB_NOT_ACTIVE"
        abort_mock.assert_not_awaited()

    async def test_409_when_already_failed(self, client: AsyncClient, mock_db, monkeypatch):
        monkeypatch.setattr("app.api.v1.admin.abort_arq_job", AsyncMock())
        job = make_job(status="failed")
        mock_db.get = AsyncMock(return_value=job)
        resp = await client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
        assert resp.status_code == 409

    async def test_stops_active_job_and_forces_failed(self, client: AsyncClient, mock_db, monkeypatch):
        abort_mock = AsyncMock(return_value=True)
        monkeypatch.setattr("app.api.v1.admin.abort_arq_job", abort_mock)
        job = make_job(status="processing", arq_job_id="arq-xyz")
        mock_db.get = AsyncMock(return_value=job)
        added = []
        mock_db.add = MagicMock(side_effect=lambda o: added.append(o))

        resp = await client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["status"] == "failed"
        assert data["error_message"] == "Annulé par l'admin"
        # review 7.7 D2 : abort confirmé → aborted=True remonté au client
        assert data["aborted"] is True

        # Statut DB forcé indépendamment de l'abort
        assert job.status == "failed"
        assert job.error_message == "Annulé par l'admin"
        # abort ARQ appelé avec l'arq_job_id
        abort_mock.assert_awaited_once_with("arq-xyz")
        # event timeline cancelled ajouté
        events = [o for o in added if isinstance(o, GenerationJobEvent)]
        assert len(events) == 1
        assert events[0].event_type == "cancelled"
        mock_db.commit.assert_awaited()

    async def test_forces_status_even_without_arq_job_id(self, client: AsyncClient, mock_db, monkeypatch):
        abort_mock = AsyncMock(return_value=True)
        monkeypatch.setattr("app.api.v1.admin.abort_arq_job", abort_mock)
        job = make_job(status="ocr_complete", arq_job_id=None)
        mock_db.get = AsyncMock(return_value=job)

        resp = await client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        # pas d'arq_job_id → pas d'abort, mais statut quand même forcé
        abort_mock.assert_not_awaited()
        assert job.status == "failed"
        assert job.error_message == "Annulé par l'admin"
        # review 7.7 D2 : pas d'abort tenté → aborted=False
        assert resp.json()["data"]["aborted"] is False

    async def test_aborted_false_when_abort_not_confirmed(self, client: AsyncClient, mock_db, monkeypatch):
        """review 7.7 D2 — abort échoué (Redis down / job fini) → aborted=False mais statut forcé."""
        abort_mock = AsyncMock(return_value=False)
        monkeypatch.setattr("app.api.v1.admin.abort_arq_job", abort_mock)
        job = make_job(status="processing", arq_job_id="arq-zzz")
        mock_db.get = AsyncMock(return_value=job)

        resp = await client.post(f"/v1/admin/jobs/{job.id}/stop", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        # L'abort a été tenté mais non confirmé : le client doit le savoir
        abort_mock.assert_awaited_once_with("arq-zzz")
        assert data["aborted"] is False
        # Le statut DB est tout de même forcé (endpoint seul garant)
        assert job.status == "failed"
