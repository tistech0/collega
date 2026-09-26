"""Tests POST /v1/auth/register, /login, /refresh, GET /me, PATCH /profile."""

from __future__ import annotations

import types
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import AsyncClient

from app.core.security import create_access_token, create_refresh_token, decode_token, hash_password
from app.deps import get_current_user
from app.main import app


def make_user(
    email="test@example.com",
    is_beta=False,
    is_subscribed=False,
    user_id=None,
    first_name=None,
    year_group=None,
    faculty=None,
    monthly_reloads=0,
    with_password=True,
    monthly_reloads_reset_at=None,
    reminder_hour_utc=None,
    token_version=0,
    last_seen_at=None,
):
    uid = user_id or uuid.uuid4()
    hashed = hash_password("password123") if with_password else "not-used"
    return types.SimpleNamespace(
        id=uid,
        email=email,
        hashed_password=hashed,
        is_beta=is_beta,
        is_subscribed=is_subscribed,
        first_name=first_name,
        year_group=year_group,
        faculty=faculty,
        monthly_reloads=monthly_reloads,
        monthly_reloads_reset_at=monthly_reloads_reset_at,
        reminder_hour_utc=reminder_hour_utc,
        token_version=token_version,
        last_seen_at=last_seen_at,
    )


class TestRegister:
    async def test_inscription_fermee_beta_privee(self, client: AsyncClient, mock_db):
        """Beta privée : comptes créés à la main, l'inscription répond 403 (spec v2)."""
        resp = await client.post(
            "/v1/auth/register",
            json={"email": "new@example.com", "password": "motdepasse123"},
        )
        assert resp.status_code == 403
        assert resp.json()["detail"]["code"] == "REGISTRATION_DISABLED"
        mock_db.add.assert_not_called()

    async def test_register_invalid_email(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/auth/register",
            json={"email": "not-an-email", "password": "password123"},
        )
        assert resp.status_code == 422


class TestLogin:
    async def test_login_success(self, client: AsyncClient, mock_db):
        user = make_user()
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user)))

        resp = await client.post(
            "/v1/auth/login",
            json={"email": user.email, "password": "password123"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body["data"]
        assert "refresh_token" in body["data"]

    async def test_login_emet_la_token_version_courante(self, client: AsyncClient, mock_db):
        user = make_user(token_version=4)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user)))

        resp = await client.post("/v1/auth/login", json={"email": user.email, "password": "password123"})
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert decode_token(data["access_token"])["tv"] == 4
        assert decode_token(data["refresh_token"])["tv"] == 4

    async def test_login_wrong_password(self, client: AsyncClient, mock_db):
        user = make_user()
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user)))

        resp = await client.post(
            "/v1/auth/login",
            json={"email": user.email, "password": "wrongpassword"},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "INVALID_CREDENTIALS"

    async def test_login_unknown_email(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))

        resp = await client.post(
            "/v1/auth/login",
            json={"email": "unknown@example.com", "password": "password123"},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "INVALID_CREDENTIALS"

    async def test_login_email_inconnu_verifie_quand_meme_un_hash(self, client: AsyncClient, mock_db):
        """Temps constant : bcrypt tourne aussi quand l'e-mail est inconnu (hash factice)."""
        from app.api.v1 import auth as auth_module

        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))
        with patch.object(auth_module, "verify_password", return_value=False) as verify:
            resp = await client.post("/v1/auth/login", json={"email": "inconnue@example.com", "password": "x"})
        assert resp.status_code == 401
        verify.assert_called_once_with("x", auth_module._DUMMY_HASH)


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
        # Rotation (chantier 2) : un nouveau refresh est émis à chaque renouvellement.
        assert body["data"]["refresh_token"] != refresh_token
        assert decode_token(body["data"]["refresh_token"])["type"] == "refresh"

    async def test_refresh_emet_la_token_version_courante(self, client: AsyncClient, mock_db):
        user = make_user(token_version=2)
        mock_db.get = AsyncMock(return_value=user)

        resp = await client.post(
            "/v1/auth/refresh", json={"refresh_token": create_refresh_token(str(user.id), token_version=2)}
        )
        assert resp.status_code == 200
        assert decode_token(resp.json()["data"]["access_token"])["tv"] == 2

    async def test_refresh_tv_perime_refuse(self, client: AsyncClient, mock_db):
        user = make_user(token_version=2)
        mock_db.get = AsyncMock(return_value=user)

        resp = await client.post(
            "/v1/auth/refresh", json={"refresh_token": create_refresh_token(str(user.id), token_version=1)}
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_REVOKED"

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

    async def test_tv_perime_renvoie_token_revoked(self, client: AsyncClient, mock_db):
        user = make_user(with_password=False, token_version=2)
        mock_db.get = AsyncMock(return_value=user)
        token = create_access_token(str(user.id), token_version=1)

        resp = await client.get("/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_REVOKED"

    async def test_jeton_sans_tv_accepte_si_version_0_refuse_sinon(self):
        """Transition : un jeton émis avant le chantier 2 (sans `tv`) passe tant que version == 0."""
        import jwt
        import pytest
        from fastapi import Request

        from app.core.config import settings
        from app.core.errors import AppError

        user = make_user(with_password=False, token_version=0)
        db = MagicMock(get=AsyncMock(return_value=user))
        legacy = jwt.encode(
            {"sub": str(user.id), "type": "access", "exp": datetime.now(UTC) + timedelta(minutes=5)},
            settings.secret_key,
            algorithm="HS256",
        )
        request = Request({"type": "http", "headers": [], "state": {}})
        assert await get_current_user(request, f"Bearer {legacy}", db) is user

        user.token_version = 1
        with pytest.raises(AppError) as exc:
            await get_current_user(request, f"Bearer {legacy}", db)
        assert exc.value.status_code == 401
        assert exc.value.code == "TOKEN_REVOKED"

    async def test_short_session_applique_aussi_tv(self):
        import pytest
        from fastapi import Request

        from app.core.errors import AppError
        from app.deps import get_current_user_short_session

        user = make_user(with_password=False, token_version=3)
        session = MagicMock(get=AsyncMock(return_value=user))
        factory = MagicMock()
        factory.return_value.__aenter__ = AsyncMock(return_value=session)
        factory.return_value.__aexit__ = AsyncMock(return_value=False)
        token = create_access_token(str(user.id), token_version=2)
        request = Request({"type": "http", "headers": [], "state": {}})
        with patch("app.core.database.async_session_factory", factory), pytest.raises(AppError) as exc:
            await get_current_user_short_session(request, f"Bearer {token}")
        assert exc.value.status_code == 401
        assert exc.value.code == "TOKEN_REVOKED"

    async def test_beta_user_flag_in_token_response(self, client: AsyncClient, mock_db):
        user = make_user(is_beta=True)
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user)))
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda u: setattr(u, "id", user.id))

        resp = await client.post(
            "/v1/auth/register",
            json={"email": user.email, "password": "password123"},
        )
        # L'utilisateur beta est déjà en base (409) ou on teste login
        # Ici on teste via login
        mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=user)))
        resp = await client.post(
            "/v1/auth/login",
            json={"email": user.email, "password": "password123"},
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["is_beta"] is True


class TestGetMe:
    async def test_get_me_returns_profile_fields(self, client: AsyncClient, mock_db):
        user = make_user(
            first_name="Marie",
            year_group="4e année",
            faculty="Paris 6",
            monthly_reloads=2,
            with_password=False,
            monthly_reloads_reset_at=datetime.now(UTC) + timedelta(days=5),
        )
        app.dependency_overrides[get_current_user] = lambda: user
        try:
            with patch("app.services.app_settings.settings") as mock_settings:
                mock_settings.monthly_reloads_max = 3
                resp = await client.get("/v1/auth/me")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["first_name"] == "Marie"
        assert data["year_group"] == "4e année"
        assert data["faculty"] == "Paris 6"
        assert data["monthly_reloads"] == 2
        assert data["monthly_reloads_max"] == 3

    async def test_get_me_quota_du_mois_en_cours_et_rappel(self, client: AsyncClient, mock_db):
        """Profil (story 8.14) : réimports du mois en cours + date de renouvellement + rappel."""
        reset = datetime.now(UTC) + timedelta(days=5)
        user = make_user(with_password=False, monthly_reloads=2, monthly_reloads_reset_at=reset, reminder_hour_utc=6)
        app.dependency_overrides[get_current_user] = lambda: user
        try:
            with patch("app.services.app_settings.settings") as mock_settings:
                mock_settings.monthly_reloads_max = 3
                resp = await client.get("/v1/auth/me")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        data = resp.json()["data"]
        assert data["monthly_reloads"] == 2
        assert datetime.fromisoformat(data["monthly_reloads_reset_at"]) == reset
        assert data["reminder_hour_utc"] == 6

    async def test_get_me_quota_perime_repart_a_zero(self, client: AsyncClient, mock_db):
        """Mois passé : le compteur stocké n'est plus le bon, /me dit 0 et la prochaine date."""
        user = make_user(
            with_password=False,
            monthly_reloads=3,
            monthly_reloads_reset_at=datetime.now(UTC) - timedelta(days=2),
        )
        app.dependency_overrides[get_current_user] = lambda: user
        try:
            with patch("app.services.app_settings.settings") as mock_settings:
                mock_settings.monthly_reloads_max = 3
                resp = await client.get("/v1/auth/me")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        data = resp.json()["data"]
        assert data["monthly_reloads"] == 0
        assert datetime.fromisoformat(data["monthly_reloads_reset_at"]) > datetime.now(UTC)
        assert data["reminder_hour_utc"] is None

    async def test_get_me_null_profile_fields(self, client: AsyncClient, mock_db):
        user = make_user(with_password=False)
        app.dependency_overrides[get_current_user] = lambda: user
        try:
            with patch("app.services.app_settings.settings") as mock_settings:
                mock_settings.monthly_reloads_max = 3
                resp = await client.get("/v1/auth/me")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["first_name"] is None
        assert data["year_group"] is None
        assert data["faculty"] is None

    async def test_get_me_unauthorized(self, client: AsyncClient, mock_db):
        resp = await client.get("/v1/auth/me")
        assert resp.status_code == 401


class TestDeleteAccount:
    async def test_delete_account_success(self, client: AsyncClient, mock_db):
        user = make_user(with_password=False)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.delete = AsyncMock()
        mock_db.commit = AsyncMock()
        token = create_access_token(str(user.id))
        response = await client.delete(
            "/v1/auth/account",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        mock_db.delete.assert_awaited_once_with(user)
        mock_db.commit.assert_awaited()  # + commit de la purge du contenu (chantier 1)

    async def test_delete_account_unauthorized(self, client: AsyncClient, mock_db):
        response = await client.delete("/v1/auth/account")
        assert response.status_code == 401


class TestUpdateProfile:
    async def test_patch_profile_updates_fields(self, client: AsyncClient, mock_db):
        user = make_user(with_password=False)
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.commit = AsyncMock()
        try:
            resp = await client.patch(
                "/v1/auth/profile",
                json={"first_name": "Jean", "year_group": "3e année", "faculty": "Lyon"},
            )
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["first_name"] == "Jean"
        assert data["year_group"] == "3e année"
        assert data["faculty"] == "Lyon"

    async def test_patch_profile_strips_whitespace(self, client: AsyncClient, mock_db):
        user = make_user(with_password=False)
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.commit = AsyncMock()
        try:
            resp = await client.patch(
                "/v1/auth/profile",
                json={"first_name": "  Alice  ", "year_group": ""},
            )
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["first_name"] == "Alice"
        assert data["year_group"] is None

    async def test_patch_profile_unauthorized(self, client: AsyncClient, mock_db):
        resp = await client.patch("/v1/auth/profile", json={"first_name": "Test"})
        assert resp.status_code == 401
