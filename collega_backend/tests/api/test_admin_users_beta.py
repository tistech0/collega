"""Tests GET /v1/admin/users et PATCH /v1/admin/users/{id}/beta."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


def make_user(user_id=None, is_beta=False, is_subscribed=False):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="user@test.com",
        is_beta=is_beta,
        is_subscribed=is_subscribed,
        monthly_reloads=0,
    )


class TestGetUsers:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get("/v1/admin/users")
        assert resp.status_code == 401

    async def test_empty_users_list(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[]))))
        )
        resp = await client.get("/v1/admin/users", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["data"] == []
        assert body["total"] == 0

    async def test_returns_users_list(self, client: AsyncClient, mock_db):
        user1 = make_user(is_beta=True)
        user2 = make_user(is_subscribed=True)

        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[user1, user2])))
            )
        )

        resp = await client.get("/v1/admin/users", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 2
        assert body["data"][0]["is_beta"] is True
        assert body["data"][1]["is_subscribed"] is True

    async def test_response_has_data_wrapper(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
            )
        )
        resp = await client.get("/v1/admin/users", auth=ADMIN_AUTH)
        assert "data" in resp.json()
        assert "total" in resp.json()


class TestPatchUserBeta:
    async def test_401_without_credentials(self, client: AsyncClient):
        user_id = str(uuid.uuid4())
        resp = await client.patch(
            f"/v1/admin/users/{user_id}/beta", json={"is_beta": True}
        )
        assert resp.status_code == 401

    async def test_404_for_unknown_user(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        user_id = str(uuid.uuid4())
        resp = await client.patch(
            f"/v1/admin/users/{user_id}/beta",
            json={"is_beta": True},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"

    async def test_set_is_beta_true(self, client: AsyncClient, mock_db):
        user = make_user(is_beta=False)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        resp = await client.patch(
            f"/v1/admin/users/{user.id}/beta",
            json={"is_beta": True},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["data"]["is_beta"] is True
        assert body["data"]["user_id"] == str(user.id)
        mock_db.commit.assert_called_once()

    async def test_set_is_beta_false(self, client: AsyncClient, mock_db):
        user = make_user(is_beta=True)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        resp = await client.patch(
            f"/v1/admin/users/{user.id}/beta",
            json={"is_beta": False},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["is_beta"] is False
