"""Tests GET /v1/admin/jobs/{job_id} (détail + timeline + OCR) — Story 7.7 AC #1/#2."""
from __future__ import annotations

import types
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def make_job(job_id=None, college_id=None, status="processing"):
    return types.SimpleNamespace(
        id=job_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        user_id=uuid.uuid4(),
        status=status,
        arq_job_id="arq-123",
        pdf_hash="abc123",
        hash_shared=False,
        card_count=12,
        error_message=None,
        input_tokens=1_000_000,
        output_tokens=1_000_000,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )


def make_college(college_id=None):
    return types.SimpleNamespace(
        id=college_id or uuid.uuid4(),
        status="processing",
        ocr_page_progress=4,
        total_pages=10,
    )


def make_event(event_type, created_at, message=None, page=None, total=None):
    return types.SimpleNamespace(
        event_type=event_type,
        message=message,
        page=page,
        total=total,
        created_at=created_at,
    )


def _scalars_result(items):
    return MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))


def _tuples_result(rows):
    return MagicMock(all=MagicMock(return_value=rows))


class TestJobDetail:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get(f"/v1/admin/jobs/{uuid.uuid4()}")
        assert resp.status_code == 401

    async def test_404_for_unknown_job(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.get(f"/v1/admin/jobs/{uuid.uuid4()}", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "JOB_NOT_FOUND"

    async def test_returns_detail_timeline_and_items(self, client: AsyncClient, mock_db):
        college = make_college()
        job = make_job(college_id=college.id)
        # db.get : 1) job, 2) college
        mock_db.get = AsyncMock(side_effect=[job, college])

        t0 = datetime.now(timezone.utc)
        events = [
            make_event("ocr_started", t0, total=10),
            make_event("ocr_progress", t0 + timedelta(seconds=5), page=5, total=10),
            make_event("ocr_complete", t0 + timedelta(seconds=10), message="8 items"),
        ]
        items_rows = [(1, 0.92, False), (2, 0.4, True)]
        # db.execute : 1) events (scalars().all()), 2) items (.all())
        mock_db.execute = AsyncMock(side_effect=[_scalars_result(events), _tuples_result(items_rows)])

        resp = await client.get(f"/v1/admin/jobs/{job.id}", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]

        # Détail brut
        assert data["job_id"] == str(job.id)
        assert data["college_id"] == str(college.id)
        assert data["status"] == "processing"
        assert data["arq_job_id"] == "arq-123"
        assert data["pdf_hash"] == "abc123"
        assert data["hash_shared"] is False
        assert data["card_count"] == 12
        assert data["created_at"] is not None

        # Progression OCR du college
        assert data["ocr_page_progress"] == 4
        assert data["total_pages"] == 10
        assert data["college_status"] == "processing"

        # Timeline ordonnée
        assert [e["event_type"] for e in data["timeline"]] == [
            "ocr_started",
            "ocr_progress",
            "ocr_complete",
        ]
        assert data["timeline"][1]["page"] == 5
        assert data["timeline"][1]["total"] == 10

        # Confiance OCR par item
        assert len(data["items"]) == 2
        assert data["items"][0]["item_number"] == 1
        assert data["items"][1]["low_confidence"] is True

        # Story 7.8 — coût/import (additif). 1M in + 1M out = (3+15) USD × 0.92 = 16.56 €.
        assert data["input_tokens"] == 1_000_000
        assert data["output_tokens"] == 1_000_000
        assert data["cost_eur"] == 16.56

    async def test_handles_missing_college_gracefully(self, client: AsyncClient, mock_db):
        job = make_job()
        # job présent mais college absent (orphan) → valeurs par défaut, pas de 500
        mock_db.get = AsyncMock(side_effect=[job, None])
        mock_db.execute = AsyncMock(side_effect=[_scalars_result([]), _tuples_result([])])

        resp = await client.get(f"/v1/admin/jobs/{job.id}", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["ocr_page_progress"] == 0
        assert data["total_pages"] is None
        assert data["college_status"] == "unknown"
        assert data["timeline"] == []
        assert data["items"] == []
