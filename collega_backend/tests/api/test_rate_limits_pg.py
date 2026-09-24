"""Limites de débit et tailles d'entrée (chantier 2 § 4) — Postgres.

Les requêtes portent de vrais jetons d'accès : `get_current_user` s'exécute réellement et
peuple `request.state.user_id`, lu par la clé « par utilisatrice » du limiteur.
"""

from __future__ import annotations

import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.security import create_access_token
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_user

pytestmark = pytest.mark.pg

BAD_ADMIN = ("admin", "mauvais")


async def _user_headers(pg_factory) -> dict[str, str]:
    async with pg_factory() as db:
        user = await make_user(db)
        await db.commit()
    return {"Authorization": f"Bearer {create_access_token(str(user.id))}"}


def _assert_rate_limited(resp) -> None:
    assert resp.status_code == 429, resp.text
    assert resp.json()["detail"]["code"] == "RATE_LIMITED"
    assert int(resp.headers["Retry-After"]) > 0


# ── Console admin : seuls les échecs comptent (10/min/IP) ─────────────────────


async def test_admin_onzieme_echec_429_meme_avec_les_bons_identifiants(pg_client):
    for _ in range(10):
        resp = await pg_client.get("/v1/admin/config", auth=BAD_ADMIN)
        assert resp.status_code == 401
        assert resp.headers["WWW-Authenticate"] == "Basic"
        assert resp.json()["detail"]["code"] == "INVALID_ADMIN_CREDENTIALS"

    _assert_rate_limited(await pg_client.get("/v1/admin/config", auth=BAD_ADMIN))
    # Budget épuisé : 429 avant même de comparer les identifiants.
    _assert_rate_limited(await pg_client.get("/v1/admin/config", auth=ADMIN_AUTH))


async def test_admin_authentifie_jamais_limite(pg_client):
    for _ in range(20):
        resp = await pg_client.get("/v1/admin/config", auth=ADMIN_AUTH)
        assert resp.status_code == 200, resp.text


async def test_admin_succes_ne_remettent_pas_a_zero_ni_ne_comptent(pg_client):
    for _ in range(9):
        assert (await pg_client.get("/v1/admin/config", auth=BAD_ADMIN)).status_code == 401
    for _ in range(20):
        assert (await pg_client.get("/v1/admin/config", auth=ADMIN_AUTH)).status_code == 200
    assert (await pg_client.get("/v1/admin/config", auth=BAD_ADMIN)).status_code == 401  # 10e échec
    _assert_rate_limited(await pg_client.get("/v1/admin/config", auth=BAD_ADMIN))  # 11e


async def test_admin_echecs_comptes_par_ip(pg_client):
    from app.main import app

    for _ in range(11):
        await pg_client.get("/v1/admin/config", auth=BAD_ADMIN)
    other = AsyncClient(transport=ASGITransport(app=app, client=("198.51.100.9", 4321)), base_url="http://test")
    async with other:
        assert (await other.get("/v1/admin/config", auth=ADMIN_AUTH)).status_code == 200


# ── /v1/auth/refresh : 30/min/IP ──────────────────────────────────────────────


async def test_refresh_31e_appel_429(pg_client):
    for _ in range(30):
        resp = await pg_client.post("/v1/auth/refresh", json={"refresh_token": "invalide"})
        assert resp.status_code == 401
    _assert_rate_limited(await pg_client.post("/v1/auth/refresh", json={"refresh_token": "invalide"}))


# ── Évaluation sémantique : 30/min par utilisatrice ───────────────────────────


async def test_drill_31e_appel_429_par_utilisatrice(pg_client, pg_factory):
    alice, bob = await _user_headers(pg_factory), await _user_headers(pg_factory)
    url = f"/v1/flash-cards/{uuid.uuid4()}/evaluate-semantic"
    body = {"user_answer": "une réponse"}

    for _ in range(30):
        assert (await pg_client.post(url, json=body, headers=alice)).status_code == 404
    _assert_rate_limited(await pg_client.post(url, json=body, headers=alice))
    # Même IP, autre utilisatrice : pas bloquée.
    assert (await pg_client.post(url, json=body, headers=bob)).status_code == 404


async def test_drill_user_answer_max_2000(pg_client, pg_factory):
    headers = await _user_headers(pg_factory)
    url = f"/v1/flash-cards/{uuid.uuid4()}/evaluate-semantic"

    resp = await pg_client.post(url, json={"user_answer": "a" * 2001}, headers=headers)
    assert resp.status_code == 422 and resp.json()["detail"]["code"] == "VALIDATION_ERROR"
    assert (await pg_client.post(url, json={"user_answer": "a" * 2000}, headers=headers)).status_code == 404


# ── Régénération : 10/h par utilisatrice ──────────────────────────────────────


async def test_regeneration_11e_appel_429_par_utilisatrice(pg_client, pg_factory):
    alice, bob = await _user_headers(pg_factory), await _user_headers(pg_factory)
    url = f"/v1/flash-cards/{uuid.uuid4()}/regenerate"

    for _ in range(10):
        assert (await pg_client.post(url, json={"user_note": None}, headers=alice)).status_code == 404
    _assert_rate_limited(await pg_client.post(url, json={"user_note": None}, headers=alice))
    assert (await pg_client.post(url, json={"user_note": None}, headers=bob)).status_code == 404


async def test_regeneration_user_note_max_2000(pg_client, pg_factory):
    headers = await _user_headers(pg_factory)
    url = f"/v1/flash-cards/{uuid.uuid4()}/regenerate"

    resp = await pg_client.post(url, json={"user_note": "n" * 2001}, headers=headers)
    assert resp.status_code == 422 and resp.json()["detail"]["code"] == "VALIDATION_ERROR"
    assert (await pg_client.post(url, json={"user_note": "n" * 2000}, headers=headers)).status_code == 404
