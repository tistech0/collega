import asyncio

import pytest
from httpx import AsyncClient

from app.api.v1 import health


async def _ok() -> None:
    return None


async def _boom() -> None:
    raise ConnectionError("down")


async def _hang() -> None:
    await asyncio.sleep(10)


@pytest.mark.asyncio
async def test_health_ok_when_db_and_redis_answer(client: AsyncClient, monkeypatch) -> None:
    monkeypatch.setattr(health, "check_db", _ok)
    monkeypatch.setattr(health, "check_redis", _ok)

    response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"data": {"status": "ok", "checks": {"db": "ok", "redis": "ok"}}}


@pytest.mark.asyncio
async def test_health_503_names_the_failing_component(client: AsyncClient, monkeypatch) -> None:
    monkeypatch.setattr(health, "check_db", _ok)
    monkeypatch.setattr(health, "check_redis", _boom)

    response = await client.get("/health")

    assert response.status_code == 503
    assert response.json() == {"data": {"status": "degraded", "checks": {"db": "ok", "redis": "error"}}}


@pytest.mark.asyncio
async def test_health_times_out_a_hanging_dependency(client: AsyncClient, monkeypatch) -> None:
    monkeypatch.setattr(health, "check_db", _hang)
    monkeypatch.setattr(health, "check_redis", _ok)
    monkeypatch.setattr(health, "CHECK_TIMEOUT_S", 0.05)

    response = await client.get("/health")

    assert response.status_code == 503
    assert response.json()["data"]["checks"] == {"db": "error", "redis": "ok"}
