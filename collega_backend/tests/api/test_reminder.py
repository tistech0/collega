"""Tests endpoints rappel quotidien — AC3, AC4 (Story 4.5)."""
from __future__ import annotations

import types
import uuid

import pytest
from httpx import AsyncClient

from app.deps import get_current_user


def _make_user():
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        email="test@example.com",
        is_subscribed=True,
        is_beta=False,
        apns_token="abc123",
        reminder_hour_utc=None,
    )


class TestSetReminder:
    async def test_set_reminder_ok(self, client: AsyncClient, mock_db):
        """POST /v1/notifications/reminder avec hour_utc valide → 200 et persistance."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        resp = await client.post(
            "/v1/notifications/reminder",
            json={"hour_utc": 7},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["reminder_enabled"] is True
        assert data["hour_utc"] == 7
        assert user.reminder_hour_utc == 7
        mock_db.commit.assert_called_once()

        app.dependency_overrides.clear()

    async def test_set_reminder_hour_invalide(self, client: AsyncClient, mock_db):
        """POST /v1/notifications/reminder avec hour_utc=25 → 422."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        resp = await client.post(
            "/v1/notifications/reminder",
            json={"hour_utc": 25},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 422

        app.dependency_overrides.clear()

    async def test_set_reminder_hour_negatif(self, client: AsyncClient, mock_db):
        """POST /v1/notifications/reminder avec hour_utc=-1 → 422."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        resp = await client.post(
            "/v1/notifications/reminder",
            json={"hour_utc": -1},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 422

        app.dependency_overrides.clear()

    async def test_set_reminder_minuit_ok(self, client: AsyncClient, mock_db):
        """POST /v1/notifications/reminder avec hour_utc=0 → 200 (minuit valide)."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        resp = await client.post(
            "/v1/notifications/reminder",
            json={"hour_utc": 0},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 200
        assert user.reminder_hour_utc == 0

        app.dependency_overrides.clear()


class TestClearReminder:
    async def test_clear_reminder_ok(self, client: AsyncClient, mock_db):
        """DELETE /v1/notifications/reminder → 200, reminder_hour_utc=None."""
        from app.main import app

        user = _make_user()
        user.reminder_hour_utc = 7
        app.dependency_overrides[get_current_user] = lambda: user

        resp = await client.delete(
            "/v1/notifications/reminder",
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["reminder_enabled"] is False
        assert user.reminder_hour_utc is None
        mock_db.commit.assert_called_once()

        app.dependency_overrides.clear()
