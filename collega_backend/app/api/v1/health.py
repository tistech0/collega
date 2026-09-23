"""Santé du service : sondée chaque minute par le script de supervision du NAS
(collega-health) et par les healthchecks Docker. 503 si Postgres ou Redis ne répond pas."""
import asyncio
import logging

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from redis.asyncio import Redis
from sqlalchemy import text

from app.core.config import settings
from app.core.database import engine

logger = logging.getLogger(__name__)
router = APIRouter()

CHECK_TIMEOUT_S = 3.0


async def check_db() -> None:
    # Connexion courte prise directement sur l'engine : pas de session gardée.
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))


async def check_redis() -> None:
    client = Redis.from_url(settings.redis_url, socket_connect_timeout=CHECK_TIMEOUT_S)
    try:
        await client.ping()
    finally:
        await client.aclose()


async def _run(name: str, check) -> str:
    try:
        await asyncio.wait_for(check(), timeout=CHECK_TIMEOUT_S)
        return "ok"
    except Exception as exc:
        logger.warning("Health check %s failed: %r", name, exc)
        return "error"


@router.get("/health")
async def health_check() -> JSONResponse:
    db, redis = await asyncio.gather(_run("db", check_db), _run("redis", check_redis))
    checks = {"db": db, "redis": redis}
    healthy = all(v == "ok" for v in checks.values())
    return JSONResponse(
        status_code=200 if healthy else 503,
        content={"data": {"status": "ok" if healthy else "degraded", "checks": checks}},
    )
