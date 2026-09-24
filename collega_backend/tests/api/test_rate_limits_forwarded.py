"""Clés de limite derrière la chaîne de proxys de prod (chantier 2 § 4, correctif 1).

Pair de connexion = NPM (réseau Docker 172.16.0.0/12). NPM ajoute à X-Forwarded-For
l'adresse qui s'est connectée à lui : cloudflared (172.23.0.3) pour le chemin public,
192.168.x pour le LAN. CF-Connecting-IP n'est cru que sur le chemin cloudflared.
"""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.database import get_db
from app.core.limiter import limiter
from app.main import app

NPM = ("172.18.0.5", 4321)
CLOUDFLARED = "172.23.0.3"
BAD_ADMIN = ("admin", "mauvais")


@pytest.fixture
async def npm_client(mock_db, fake_arq):
    from tests.fakes.fake_arq import override_arq

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_get_db
    override_arq(fake_arq)
    async with AsyncClient(transport=ASGITransport(app=app, client=NPM), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


def _via_lan(ip: str, forged_cf: str | None = None) -> dict[str, str]:
    headers = {"X-Forwarded-For": f"6.6.6.6, {ip}"}
    if forged_cf:
        headers["CF-Connecting-IP"] = forged_cf
    return headers


def _via_cloudflare(ip: str) -> dict[str, str]:
    return {"CF-Connecting-IP": ip, "X-Forwarded-For": f"{ip}, {CLOUDFLARED}"}


async def _login(client, headers):
    return await client.post("/v1/auth/login", json={"email": "x@test.fr", "password": "mauvais"}, headers=headers)


async def test_login_cle_suit_le_dernier_saut_x_forwarded_for(npm_client):
    for _ in range(5):
        assert (await _login(npm_client, _via_lan("192.168.1.20"))).status_code == 401
    assert (await _login(npm_client, _via_lan("192.168.1.20"))).status_code == 429
    assert (await _login(npm_client, _via_lan("192.168.1.21"))).status_code == 401


async def test_login_cle_suit_cf_connecting_ip_via_cloudflared(npm_client):
    for _ in range(5):
        assert (await _login(npm_client, _via_cloudflare("203.0.113.1"))).status_code == 401
    assert (await _login(npm_client, _via_cloudflare("203.0.113.1"))).status_code == 429
    # Même cloudflared, autre client Cloudflare : pas bloqué.
    assert (await _login(npm_client, _via_cloudflare("203.0.113.2"))).status_code == 401


async def test_cf_connecting_ip_forge_depuis_le_lan_ignore(npm_client):
    # Changer de CF-Connecting-IP à chaque essai ne contourne pas la limite de l'hôte LAN.
    for i in range(5):
        resp = await _login(npm_client, _via_lan("192.168.1.20", forged_cf=f"203.0.113.{i + 10}"))
        assert resp.status_code == 401
    resp = await _login(npm_client, _via_lan("192.168.1.20", forged_cf="203.0.113.99"))
    assert resp.status_code == 429


async def test_refresh_cle_suit_l_ip_transmise(npm_client):
    body = {"refresh_token": "invalide"}
    for _ in range(30):
        assert (
            await npm_client.post("/v1/auth/refresh", json=body, headers=_via_cloudflare("203.0.113.1"))
        ).status_code == 401
    assert (
        await npm_client.post("/v1/auth/refresh", json=body, headers=_via_cloudflare("203.0.113.1"))
    ).status_code == 429
    assert (await npm_client.post("/v1/auth/refresh", json=body, headers=_via_lan("192.168.1.20"))).status_code == 401


async def test_admin_echecs_cle_suit_l_ip_transmise(npm_client):
    for _ in range(10):
        resp = await npm_client.get("/v1/admin/config", auth=BAD_ADMIN, headers=_via_cloudflare("203.0.113.1"))
        assert resp.status_code == 401
    resp = await npm_client.get("/v1/admin/config", auth=BAD_ADMIN, headers=_via_cloudflare("203.0.113.1"))
    assert resp.status_code == 429
    resp = await npm_client.get("/v1/admin/config", auth=BAD_ADMIN, headers=_via_cloudflare("203.0.113.2"))
    assert resp.status_code == 401


async def test_admin_echecs_non_comptes_si_limiteur_desactive(npm_client, monkeypatch):
    monkeypatch.setattr(limiter, "enabled", False)
    for _ in range(12):
        assert (await npm_client.get("/v1/admin/config", auth=BAD_ADMIN)).status_code == 401
