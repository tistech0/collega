"""Tests POST /v1/admin/users/{user_id}/reset-quota — Story 7.6 AC #2."""

from __future__ import annotations

import types
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock

from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def make_user(user_id=None, monthly_reloads=3):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="user@test.com",
        is_beta=False,
        is_subscribed=False,
        monthly_reloads=monthly_reloads,
        monthly_reloads_reset_at=datetime.now(UTC),
        created_at=datetime.now(UTC),
    )


class TestResetQuota:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.post(f"/v1/admin/users/{uuid.uuid4()}/reset-quota")
        assert resp.status_code == 401

    async def test_404_for_unknown_user(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.post(f"/v1/admin/users/{uuid.uuid4()}/reset-quota", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"

    async def test_resets_reloads_and_reset_at(self, client: AsyncClient, mock_db):
        user = make_user(monthly_reloads=3)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.execute = AsyncMock()
        mock_db.commit = AsyncMock()

        resp = await client.post(f"/v1/admin/users/{user.id}/reset-quota", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["data"]["monthly_reloads"] == 0
        mock_db.commit.assert_awaited()

        # Effet réel : un UPDATE atomique (pas de read-modify-write) qui remet
        # compteur ET fenêtre à zéro, de sorte que le prochain réimport ré-init
        # proprement via la logique lazy de colleges.py.
        mock_db.execute.assert_awaited_once()
        stmt = mock_db.execute.await_args.args[0]
        compiled = stmt.compile()
        params = compiled.params
        assert params["monthly_reloads"] == 0
        assert params["monthly_reloads_reset_at"] is None
