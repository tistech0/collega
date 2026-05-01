"""Tests GET /v1/admin/queue — dashboard ARQ."""
from __future__ import annotations

import types
import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def make_job(college_id=None, status="generation_complete", card_count=3, error_message=None):
    cid = college_id or uuid.uuid4()
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        college_id=cid,
        status=status,
        card_count=card_count,
        error_message=error_message,
        hash_shared=False,
        created_at=datetime(2026, 4, 28, 10, 0, 0, tzinfo=timezone.utc),
    )


def make_college(college_id=None, ocr_page_progress=10, total_pages=20):
    return types.SimpleNamespace(
        id=college_id or uuid.uuid4(),
        ocr_page_progress=ocr_page_progress,
        total_pages=total_pages,
    )


class TestGetQueue:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get("/v1/admin/queue")
        assert resp.status_code == 401

    async def test_empty_queue(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(all=MagicMock(return_value=[]))
        )
        resp = await client.get("/v1/admin/queue", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["data"] == []
        assert body["total"] == 0

    async def test_queue_with_jobs(self, client: AsyncClient, mock_db):
        cid = uuid.uuid4()
        job = make_job(college_id=cid, status="generation_complete", card_count=5)
        college = make_college(college_id=cid, ocr_page_progress=15, total_pages=30)

        mock_db.execute = AsyncMock(
            return_value=MagicMock(all=MagicMock(return_value=[(job, college)]))
        )

        resp = await client.get("/v1/admin/queue", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 1
        item = body["data"][0]
        assert item["job_id"] == str(job.id)
        assert item["college_id"] == str(cid)
        assert item["status"] == "generation_complete"
        assert item["college_ocr_page_progress"] == 15
        assert item["college_total_pages"] == 30
        assert item["card_count"] == 5
        assert item["error_message"] is None
        assert "elapsed_seconds" in item
        assert isinstance(item["elapsed_seconds"], float)

    async def test_queue_includes_error_message(self, client: AsyncClient, mock_db):
        cid = uuid.uuid4()
        job = make_job(college_id=cid, status="failed", error_message="timeout")
        college = make_college(college_id=cid)

        mock_db.execute = AsyncMock(
            return_value=MagicMock(all=MagicMock(return_value=[(job, college)]))
        )

        resp = await client.get("/v1/admin/queue", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        assert resp.json()["data"][0]["error_message"] == "timeout"

    async def test_response_has_data_wrapper(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(all=MagicMock(return_value=[]))
        )
        resp = await client.get("/v1/admin/queue", auth=ADMIN_AUTH)
        body = resp.json()
        assert "data" in body
        assert "total" in body
