"""Tests POST /v1/auth/register, /login, /refresh."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from app.core.security import create_access_token, create_refresh_token, hash_password


def make_user(email="test@example.com", is_beta=False, is_subscribed=False, user_id=None):
    uid = user_id or uuid.uuid4()
    return types.SimpleNamespace(
        id=uid,
        email=email,
        hashed_password=hash_password("password123"),
        is_beta=is_beta,
        is_subscribed=is_subscribed,
    )


class TestRegister:
    async def test_register_success(self, client: AsyncClient, mock_db):
        new_user = make_user()

        def _refresh_user(u):
            u.id = new_user.id
            u.is_beta = False
            u.is_subscribed = False

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=_refresh_user)

        resp = await client.post(
            "/v1/auth/register",
            json={"email": "new@example.com", "password": "password123"},
        )
        assert resp.status_code == 201
        body = resp.json()
        assert "access_token" in body["data"]
        assert "refresh_token" in body["data"]
        assert body["data"]["token_type"] == "bearer"

    async def test_register_duplicate_email(self, client: AsyncClient, mock_db):
        existing = make_user(email="taken@example.com")
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=existing))
        )

        resp = await client.post(
            "/v1/auth/register",
            json={"email": "taken@example.com", "password": "password123"},
        )
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "EMAIL_ALREADY_EXISTS"

    async def test_register_password_too_short(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/auth/register",
            json={"email": "short@example.com", "password": "abc"},
        )
        assert resp.status_code == 422

    async def test_register_invalid_email(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/auth/register",
            json={"email": "not-an-email", "password": "password123"},
        )
        assert resp.status_code == 422


class TestLogin:
    async def test_login_success(self, client: AsyncClient, mock_db):
        user = make_user()
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user))
        )

        resp = await client.post(
            "/v1/auth/login",
            json={"email": user.email, "password": "password123"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body["data"]
        assert "refresh_token" in body["data"]

    async def test_login_wrong_password(self, client: AsyncClient, mock_db):
        user = make_user()
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user))
        )

        resp = await client.post(
            "/v1/auth/login",
            json={"email": user.email, "password": "wrongpassword"},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "INVALID_CREDENTIALS"

    async def test_login_unknown_email(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )

        resp = await client.post(
            "/v1/auth/login",
            json={"email": "unknown@example.com", "password": "password123"},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "INVALID_CREDENTIALS"


class TestRefresh:
    async def test_refresh_success(self, client: AsyncClient, mock_db):
        user = make_user()
        refresh_token = create_refresh_token(str(user.id))
        mock_db.get = AsyncMock(return_value=user)

        resp = await client.post(
            "/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body["data"]
        assert body["data"]["refresh_token"] == refresh_token

    async def test_refresh_invalid_token(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/auth/refresh",
            json={"refresh_token": "not.a.valid.token"},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_EXPIRED"

    async def test_refresh_access_token_rejected(self, client: AsyncClient, mock_db):
        user = make_user()
        access_token = create_access_token(str(user.id))

        resp = await client.post(
            "/v1/auth/refresh",
            json={"refresh_token": access_token},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_EXPIRED"


class TestGetCurrentUser:
    async def test_unauthorized_without_token(self, client: AsyncClient, mock_db):
        resp = await client.get("/v1/auth/me")
        assert resp.status_code == 401

    async def test_beta_user_flag_in_token_response(self, client: AsyncClient, mock_db):
        user = make_user(is_beta=True)
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user))
        )
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda u: setattr(u, "id", user.id))

        resp = await client.post(
            "/v1/auth/register",
            json={"email": user.email, "password": "password123"},
        )
        # L'utilisateur beta est déjà en base (409) ou on teste login
        # Ici on teste via login
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user))
        )
        resp = await client.post(
            "/v1/auth/login",
            json={"email": user.email, "password": "password123"},
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["is_beta"] is True
