"""Tests pour la dépendance require_subscription (AC #5 — FR42)."""
from __future__ import annotations

import types
import uuid

from fastapi import Depends, FastAPI
from httpx import ASGITransport, AsyncClient

from app.deps import get_current_user, require_subscription


def _make_user(is_subscribed=False, is_beta=False):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        email="test@example.com",
        is_subscribed=is_subscribed,
        is_beta=is_beta,
    )


def _make_test_app(user=None):
    """Mini-app FastAPI avec un endpoint protégé par require_subscription."""
    test_app = FastAPI()

    @test_app.get("/protected")
    async def protected(u=Depends(require_subscription)):
        return {"ok": True}

    if user is not None:
        test_app.dependency_overrides[get_current_user] = lambda: user

    return test_app


class TestRequireSubscription:
    async def test_non_authentifie_retourne_401(self):
        """Sans token → get_current_user lève 401 avant require_subscription."""
        app = _make_test_app()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.get("/protected")
        assert resp.status_code == 401

    async def test_abonne_passe_la_guard(self):
        """is_subscribed=True → 200."""
        app = _make_test_app(user=_make_user(is_subscribed=True))
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.get("/protected")
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    async def test_beta_passe_la_guard(self):
        """is_beta=True → 200."""
        app = _make_test_app(user=_make_user(is_beta=True))
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.get("/protected")
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    async def test_non_abonne_bloque_sur_route_protegee(self):
        """is_subscribed=False, is_beta=False → 403 SUBSCRIPTION_REQUIRED."""
        app = _make_test_app(user=_make_user())
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.get("/protected")
        assert resp.status_code == 403
        body = resp.json()
        assert body["detail"]["code"] == "SUBSCRIPTION_REQUIRED"

    async def test_non_abonne_message_erreur(self):
        """Corps 403 contient le message attendu."""
        app = _make_test_app(user=_make_user())
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.get("/protected")
        assert resp.json()["detail"]["message"] == "Abonnement actif requis"

    async def test_abonne_accede_route_protegee(self):
        """is_subscribed=True → corps {"ok": True}."""
        app = _make_test_app(user=_make_user(is_subscribed=True))
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.get("/protected")
        assert resp.json() == {"ok": True}

    async def test_beta_accede_route_protegee(self):
        """is_beta=True → corps {"ok": True}."""
        app = _make_test_app(user=_make_user(is_beta=True))
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.get("/protected")
        assert resp.json() == {"ok": True}
