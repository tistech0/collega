"""Rotation du refresh, logout, reset-password admin (chantier 2 § 2-3) — Postgres + Redis réel."""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime, timedelta

import jwt
from sqlalchemy import select

from app.core.config import settings
from app.core.security import decode_token, hash_password
from app.models.user import User
from tests.api_pg import ADMIN_AUTH

PASSWORD = "motdepasse123"


async def _make_user(pg_factory, *, apns_token: str | None = "apns-tok") -> User:
    async with pg_factory() as db:
        user = User(
            id=uuid.uuid4(),
            email=f"{uuid.uuid4().hex[:10]}@test.fr",
            hashed_password=hash_password(PASSWORD),
            apns_token=apns_token,
        )
        db.add(user)
        await db.commit()
        return user


async def _reload(pg_factory, user_id) -> User:
    async with pg_factory() as db:
        return (await db.execute(select(User).where(User.id == user_id))).scalar_one()


async def _login(client, email: str, password: str = PASSWORD):
    return await client.post("/v1/auth/login", json={"email": email, "password": password})


async def _refresh(client, refresh_token: str):
    return await client.post("/v1/auth/refresh", json={"refresh_token": refresh_token})


def _bearer(access: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {access}"}


def _grace_key(token: str) -> str:
    return f"refresh:grace:{decode_token(token)['jti']}"


class TestRotation:
    async def test_rotation_grace_puis_reutilisation(self, pg_client, pg_factory, token_redis):
        user = await _make_user(pg_factory)
        tokens = (await _login(pg_client, user.email)).json()["data"]
        access1, refresh1 = tokens["access_token"], tokens["refresh_token"]

        # Rotation : nouveau couple.
        resp = await _refresh(pg_client, refresh1)
        assert resp.status_code == 200
        refresh2 = resp.json()["data"]["refresh_token"]
        assert refresh2 != refresh1
        assert resp.json()["data"]["access_token"] != access1

        # Requête parallèle dans les 60 s : ancien refresh accepté.
        resp = await _refresh(pg_client, refresh1)
        assert resp.status_code == 200

        # Hors grâce : réutilisation → toutes les sessions coupées.
        await token_redis.delete(_grace_key(refresh1))
        resp = await _refresh(pg_client, refresh1)
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_REUSED"
        assert (await _reload(pg_factory, user.id)).token_version == 1

        resp = await pg_client.get("/v1/auth/me", headers=_bearer(access1))
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_REVOKED"
        resp = await _refresh(pg_client, refresh2)
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_REVOKED"

        # Une nouvelle connexion repart à la version courante.
        tokens = (await _login(pg_client, user.email)).json()["data"]
        assert decode_token(tokens["refresh_token"])["tv"] == 1
        assert (await pg_client.get("/v1/auth/me", headers=_bearer(tokens["access_token"]))).status_code == 200

    async def test_jeton_ancien_sans_tv_ni_jti_accepte_en_version_0(self, pg_client, pg_factory, token_redis):
        user = await _make_user(pg_factory)
        legacy = jwt.encode(
            {"sub": str(user.id), "type": "refresh", "exp": datetime.now(UTC) + timedelta(days=1)},
            settings.secret_key,
            algorithm="HS256",
        )
        resp = await _refresh(pg_client, legacy)
        assert resp.status_code == 200
        new_refresh = resp.json()["data"]["refresh_token"]
        assert new_refresh != legacy
        payload = decode_token(new_refresh)
        assert payload["tv"] == 0 and len(payload["jti"]) == 32


class TestLogout:
    async def test_logout_revoque_le_refresh_et_efface_apns(self, pg_client, pg_factory, token_redis):
        user = await _make_user(pg_factory)
        tokens = (await _login(pg_client, user.email)).json()["data"]
        access, refresh = tokens["access_token"], tokens["refresh_token"]

        resp = await pg_client.post("/v1/auth/logout", headers=_bearer(access), json={"refresh_token": refresh})
        assert resp.status_code == 204
        assert (await _reload(pg_factory, user.id)).apns_token is None
        assert await token_redis.get(f"revoked:jti:{decode_token(refresh)['jti']}") == b"1"

        # Idempotent.
        resp = await pg_client.post("/v1/auth/logout", headers=_bearer(access), json={"refresh_token": refresh})
        assert resp.status_code == 204

        await token_redis.delete(_grace_key(refresh))
        resp = await _refresh(pg_client, refresh)
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_REUSED"

    async def test_logout_sans_corps(self, pg_client, pg_factory, token_redis):
        user = await _make_user(pg_factory)
        access = (await _login(pg_client, user.email)).json()["data"]["access_token"]
        resp = await pg_client.post("/v1/auth/logout", headers=_bearer(access))
        assert resp.status_code == 204
        assert (await _reload(pg_factory, user.id)).apns_token is None

    async def test_logout_ignore_le_refresh_d_une_autre(self, pg_client, pg_factory, token_redis):
        alice = await _make_user(pg_factory)
        bob = await _make_user(pg_factory)
        access_a = (await _login(pg_client, alice.email)).json()["data"]["access_token"]
        refresh_b = (await _login(pg_client, bob.email)).json()["data"]["refresh_token"]

        resp = await pg_client.post("/v1/auth/logout", headers=_bearer(access_a), json={"refresh_token": refresh_b})
        assert resp.status_code == 204
        assert await token_redis.get(f"revoked:jti:{decode_token(refresh_b)['jti']}") is None

    async def test_logout_refresh_invalide_ignore(self, pg_client, pg_factory, token_redis):
        user = await _make_user(pg_factory)
        access = (await _login(pg_client, user.email)).json()["data"]["access_token"]
        resp = await pg_client.post("/v1/auth/logout", headers=_bearer(access), json={"refresh_token": "pas.un.jeton"})
        assert resp.status_code == 204

    async def test_logout_exige_un_access_token(self, pg_client):
        resp = await pg_client.post("/v1/auth/logout")
        assert resp.status_code == 401


class TestRedisCoupe:
    async def test_login_et_refresh_passent_avec_warning(self, pg_client, pg_factory, caplog):
        # Pas de fixture token_redis : le magasin pointe sur un port fermé.
        user = await _make_user(pg_factory)
        with caplog.at_level(logging.WARNING, logger="app.core.token_store"):
            resp = await _login(pg_client, user.email)
            assert resp.status_code == 200
            refresh = resp.json()["data"]["refresh_token"]
            resp = await _refresh(pg_client, refresh)
            assert resp.status_code == 200
        assert any("Redis" in r.getMessage() for r in caplog.records)
        assert all(refresh not in r.getMessage() for r in caplog.records)


class TestResetPassword:
    async def test_mot_de_passe_provisoire_et_sessions_coupees(self, pg_client, pg_factory, token_redis, caplog):
        user = await _make_user(pg_factory)
        tokens = (await _login(pg_client, user.email)).json()["data"]

        with caplog.at_level(logging.DEBUG):
            resp = await pg_client.post(f"/v1/admin/users/{user.id}/reset-password", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        temporary = resp.json()["data"]["temporary_password"]
        assert len(temporary) == 16
        assert all(temporary not in r.getMessage() for r in caplog.records)
        assert (await _reload(pg_factory, user.id)).token_version == 1

        assert (await _login(pg_client, user.email)).status_code == 401
        assert (await _login(pg_client, user.email, temporary)).status_code == 200

        resp = await _refresh(pg_client, tokens["refresh_token"])
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "TOKEN_REVOKED"
        resp = await pg_client.get("/v1/auth/me", headers=_bearer(tokens["access_token"]))
        assert resp.status_code == 401

    async def test_utilisatrice_inconnue_404(self, pg_client, token_redis):
        resp = await pg_client.post(f"/v1/admin/users/{uuid.uuid4()}/reset-password", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"

    async def test_exige_l_admin(self, pg_client):
        resp = await pg_client.post(f"/v1/admin/users/{uuid.uuid4()}/reset-password")
        assert resp.status_code == 401
