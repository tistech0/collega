"""Tests GET /v1/admin/users/{user_id} (détail) — Story 7.6 AC #3."""

from __future__ import annotations

import types
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

# Le faux db.get renvoie l'utilisateur pour toute clé : limites anti-spam injectées.
pytestmark = pytest.mark.usefixtures("default_anti_spam_limits")

ADMIN_AUTH = ("admin", "testpass")


def make_user(user_id=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="user@test.com",
        is_beta=True,
        is_subscribed=False,
        monthly_reloads=2,
        monthly_reloads_reset_at=datetime.now(UTC),
        created_at=datetime.now(UTC),
    )


def make_college(college_id=None, ref_id=12):
    return types.SimpleNamespace(
        id=college_id or uuid.uuid4(),
        college_ref_id=ref_id,
        status="generation_complete",
        reload_count=1,
        created_at=datetime.now(UTC),
    )


def make_job(college_id=None, status="generation_complete"):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        status=status,
        card_count=42,
        error_message=None,
        created_at=datetime.now(UTC),
    )


def _scalars_result(items):
    return MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))


class TestUserDetail:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get(f"/v1/admin/users/{uuid.uuid4()}")
        assert resp.status_code == 401

    async def test_404_for_unknown_user(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.get(f"/v1/admin/users/{uuid.uuid4()}", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"

    async def test_returns_user_with_colleges_and_jobs(self, client: AsyncClient, mock_db):
        user = make_user()
        college = make_college()
        job = make_job(college_id=college.id)
        mock_db.get = AsyncMock(return_value=user)
        # 1er execute → collèges, 2e execute → jobs
        mock_db.execute = AsyncMock(side_effect=[_scalars_result([college]), _scalars_result([job])])

        resp = await client.get(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["user_id"] == str(user.id)
        assert data["email"] == "user@test.com"
        assert data["is_beta"] is True
        assert data["monthly_reloads"] == 2
        assert data["monthly_reloads_max"] == 3  # défaut settings
        assert data["monthly_reloads_reset_at"] is not None
        assert data["created_at"] is not None

        assert len(data["colleges"]) == 1
        assert data["colleges"][0]["college_ref_id"] == 12
        assert data["colleges"][0]["status"] == "generation_complete"
        assert data["colleges"][0]["reload_count_max"] == 2  # défaut settings

        assert len(data["jobs"]) == 1
        assert data["jobs"][0]["card_count"] == 42
        assert data["jobs"][0]["status"] == "generation_complete"
        assert data["jobs"][0]["error_message"] is None

    async def test_empty_colleges_and_jobs(self, client: AsyncClient, mock_db):
        user = make_user()
        mock_db.get = AsyncMock(return_value=user)
        mock_db.execute = AsyncMock(side_effect=[_scalars_result([]), _scalars_result([])])

        resp = await client.get(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["colleges"] == []
        assert data["jobs"] == []
