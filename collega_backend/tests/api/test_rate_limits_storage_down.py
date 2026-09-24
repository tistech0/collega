"""Limiteur sans stockage (Redis coupé) : les requêtes passent, l'incident est journalisé (chantier 2 § 4)."""

from __future__ import annotations

import logging

import pytest
from limits.storage import storage_from_string
from limits.strategies import FixedWindowRateLimiter

from app.core.limiter import limiter


@pytest.fixture
def limiter_storage_down(monkeypatch):
    # Port fermé : chaque accès au stockage échoue aussitôt (connexion refusée).
    storage = storage_from_string("redis://127.0.0.1:1/0", socket_connect_timeout=0.2, socket_timeout=0.2)
    monkeypatch.setattr(limiter, "_storage", storage)
    monkeypatch.setattr(limiter, "_limiter", FixedWindowRateLimiter(storage))


async def test_refresh_passe_quand_le_stockage_est_coupe(client, limiter_storage_down, caplog):
    with caplog.at_level(logging.WARNING):
        resp = await client.post("/v1/auth/refresh", json={"refresh_token": "invalide"})

    assert resp.status_code == 401
    assert any(r.name == "slowapi" and r.levelno >= logging.WARNING for r in caplog.records)


async def test_echec_admin_passe_quand_le_stockage_est_coupe(client, limiter_storage_down, caplog):
    with caplog.at_level(logging.WARNING, logger="app.core.limiter"):
        resp = await client.get("/v1/admin/config", auth=("admin", "mauvais"))

    assert resp.status_code == 401
    messages = [r.getMessage() for r in caplog.records if r.name == "app.core.limiter"]
    assert any("Limiteur indisponible" in m for m in messages)
