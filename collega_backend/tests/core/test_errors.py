"""Gestionnaires d'erreurs uniformes (chantier 5 § 4) : AppError, 422, 429, 500."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import FastAPI, HTTPException, Request
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel

from app.core.errors import (
    AppError,
    conflict,
    forbidden,
    install_error_handlers,
    not_found,
    unauthorized,
    unprocessable,
)
from app.core.limiter import limiter


class _Body(BaseModel):
    count: int


def _make_app() -> FastAPI:
    app = FastAPI()
    app.state.limiter = limiter
    install_error_handlers(app)

    @app.get("/app-error")
    async def app_error() -> None:
        raise conflict("COLLEGE_RELOAD_LIMIT", "Limite atteinte", reload_count=3, reload_count_max=3)

    @app.get("/basic")
    async def basic() -> None:
        raise AppError(401, "UNAUTHORIZED", "Non autorisé", headers={"WWW-Authenticate": "Basic"})

    @app.post("/validate")
    async def validate(body: _Body) -> dict[str, int]:
        return {"count": body.count}

    @app.get("/limited")
    @limiter.limit("2/minute")
    async def limited(request: Request) -> dict[str, bool]:
        return {"ok": True}

    @app.get("/boom")
    async def boom() -> None:
        raise RuntimeError("secret interne : postgres://user:pw@host")

    @app.get("/http-exc")
    async def http_exc() -> None:
        raise HTTPException(status_code=418, detail="brut")

    return app


# Construite une seule fois : slowapi enregistre la limite par nom de fonction décorée,
# une app par test empilerait les limites de `/limited`.
_TEST_APP = _make_app()


@pytest.fixture
async def test_client():
    transport = ASGITransport(app=_TEST_APP, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


def test_factories_status_codes() -> None:
    assert not_found("X", "m").status_code == 404
    assert conflict("X", "m").status_code == 409
    assert unprocessable("X", "m").status_code == 422
    assert unauthorized("X", "m").status_code == 401
    assert forbidden("X", "m").status_code == 403
    err = unprocessable("X", "m", missing=[1])
    assert err.detail == {"code": "X", "message": "m", "missing": [1]}


async def test_app_error_with_flat_extra(test_client: AsyncClient) -> None:
    resp = await test_client.get("/app-error")
    assert resp.status_code == 409
    assert resp.json() == {
        "detail": {
            "code": "COLLEGE_RELOAD_LIMIT",
            "message": "Limite atteinte",
            "reload_count": 3,
            "reload_count_max": 3,
        }
    }


async def test_app_error_keeps_headers(test_client: AsyncClient) -> None:
    resp = await test_client.get("/basic")
    assert resp.status_code == 401
    assert resp.headers["WWW-Authenticate"] == "Basic"
    assert resp.json()["detail"]["code"] == "UNAUTHORIZED"


async def test_validation_error_format(test_client: AsyncClient) -> None:
    resp = await test_client.post("/validate", json={"count": "pas un nombre"})
    assert resp.status_code == 422
    detail = resp.json()["detail"]
    assert detail["code"] == "VALIDATION_ERROR"
    assert detail["message"] == "Requête invalide"
    assert detail["errors"] and set(detail["errors"][0]) == {"loc", "msg", "type"}
    assert detail["errors"][0]["loc"] == ["body", "count"]


async def test_rate_limited_with_retry_after(test_client: AsyncClient) -> None:
    assert (await test_client.get("/limited")).status_code == 200
    assert (await test_client.get("/limited")).status_code == 200
    resp = await test_client.get("/limited")
    assert resp.status_code == 429
    assert resp.json() == {"detail": {"code": "RATE_LIMITED", "message": "Trop de requêtes, réessayez plus tard"}}
    assert resp.headers["Retry-After"] == "60"


async def test_internal_error_does_not_leak(test_client: AsyncClient, caplog) -> None:
    with caplog.at_level("ERROR"):
        resp = await test_client.get("/boom")
    assert resp.status_code == 500
    assert resp.json() == {"detail": {"code": "INTERNAL_ERROR", "message": "Erreur interne"}}
    assert "postgres" not in resp.text
    assert any(r.exc_info for r in caplog.records)


async def test_plain_http_exception_unchanged(test_client: AsyncClient) -> None:
    resp = await test_client.get("/http-exc")
    assert resp.status_code == 418
    assert resp.json() == {"detail": "brut"}


async def test_real_app_login_rate_limited(client: AsyncClient, mock_db) -> None:
    """429 à travers le vrai limiteur de l'app (login : 5/minute)."""
    mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))
    body = {"email": "a@b.fr", "password": "x"}
    for _ in range(5):
        assert (await client.post("/v1/auth/login", json=body)).status_code == 401
    resp = await client.post("/v1/auth/login", json=body)
    assert resp.status_code == 429
    assert resp.json()["detail"]["code"] == "RATE_LIMITED"
    assert resp.headers["Retry-After"] == "60"


async def test_real_app_validation_error(client: AsyncClient) -> None:
    resp = await client.post("/v1/auth/login", json={"email": "a@b.fr"})
    assert resp.status_code == 422
    assert resp.json()["detail"]["code"] == "VALIDATION_ERROR"
