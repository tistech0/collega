"""Tests POST /v1/admin/users (create-user admin) — Story 7.6 AC #1.

Inclut un test de non-régression : POST /v1/auth/register reste 403.
"""

from __future__ import annotations

import uuid
from unittest.mock import AsyncMock, MagicMock

from httpx import AsyncClient
from sqlalchemy.exc import IntegrityError

ADMIN_AUTH = ("admin", "testpass")


class TestCreateUser:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.post(
            "/v1/admin/users",
            json={"email": "new@test.com", "password": "password123"},
        )
        assert resp.status_code == 401

    async def test_creates_user_returns_201(self, client: AsyncClient, mock_db):
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()

        resp = await client.post(
            "/v1/admin/users",
            json={"email": "Testeuse@Example.com", "password": "password123"},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 201
        body = resp.json()
        assert "data" in body
        data = body["data"]
        # email normalisé (strip + lower)
        assert data["email"] == "testeuse@example.com"
        assert data["is_beta"] is False
        # Invariants compte neuf garantis par l'endpoint (pas par un mock) :
        assert data["is_subscribed"] is False
        assert data["monthly_reloads"] == 0
        assert data["monthly_reloads_max"] >= 1
        # user_id est un UUID valide généré par l'endpoint
        uuid.UUID(data["user_id"])
        # add réel de l'objet User construit + commit
        mock_db.add.assert_called_once()
        added = mock_db.add.call_args.args[0]
        assert added.email == "testeuse@example.com"
        assert added.is_beta is False
        mock_db.commit.assert_awaited()

    async def test_is_beta_true_honored(self, client: AsyncClient, mock_db):
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()

        resp = await client.post(
            "/v1/admin/users",
            json={"email": "beta@test.com", "password": "password123", "is_beta": True},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 201
        assert resp.json()["data"]["is_beta"] is True
        # le flag est bien porté par l'objet persisté
        assert mock_db.add.call_args.args[0].is_beta is True

    async def test_409_on_duplicate_email(self, client: AsyncClient, mock_db):
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock(side_effect=IntegrityError("", "", Exception()))
        mock_db.rollback = AsyncMock()

        resp = await client.post(
            "/v1/admin/users",
            json={"email": "dup@test.com", "password": "password123"},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "EMAIL_ALREADY_EXISTS"
        mock_db.rollback.assert_awaited()

    async def test_422_on_short_password(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/admin/users",
            json={"email": "short@test.com", "password": "short"},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 422

    async def test_422_on_invalid_email(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/admin/users",
            json={"email": "not-an-email", "password": "password123"},
            auth=ADMIN_AUTH,
        )
        assert resp.status_code == 422


class TestRegisterStillDisabled:
    """Non-régression : create-user admin ne réactive PAS l'inscription publique."""

    async def test_public_register_still_403(self, client: AsyncClient):
        resp = await client.post(
            "/v1/auth/register",
            json={"email": "public@test.com", "password": "password123"},
        )
        assert resp.status_code == 403
        assert resp.json()["detail"]["code"] == "REGISTRATION_DISABLED"
