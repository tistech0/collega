"""Configuration pytest commune.

Utilise SQLite (aiosqlite) en tests pour éviter asyncpg et PostgreSQL.
Les dépendances DB et ARQ sont mockées via override FastAPI.
"""

import os

# Fixtures partagées : Postgres (pg_engine, pg_factory, pg_session, pg_client) et SQLite (sqlite_session).
pytest_plugins = ["tests.pg", "tests.api_pg", "tests.sqlite_db"]

# Doit être défini AVANT l'import du module settings (module-level Settings())
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./test.db")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("RATE_LIMIT_STORAGE_URI", "memory://")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-pytest-only")
os.environ.setdefault("CLAUDE_API_KEY", "test-key")
os.environ.setdefault("ADMIN_USERNAME", "admin")
os.environ.setdefault("ADMIN_PASSWORD", "testpass")
os.environ.setdefault("REVENUECAT_WEBHOOK_SECRET", "test-rc-secret")

from unittest.mock import AsyncMock, MagicMock

import pytest

# Override de create_async_engine pour SQLite (sans pool_size / max_overflow)
import sqlalchemy.ext.asyncio as _sa_async
from httpx import ASGITransport, AsyncClient

_orig_create = _sa_async.create_async_engine


def _patched_create_engine(url, **kwargs):
    # Supprimer les options non supportées par SQLite
    kwargs.pop("pool_size", None)
    kwargs.pop("max_overflow", None)
    return _orig_create(url, **kwargs)


_sa_async.create_async_engine = _patched_create_engine  # type: ignore[assignment]

from app.core.database import get_db
from app.main import app
from tests.fakes.fake_arq import make_fake_arq, override_arq

# Restaurer après import
_sa_async.create_async_engine = _orig_create  # type: ignore[assignment]


def make_mock_db():
    """Crée un AsyncSession mock complet."""
    db = AsyncMock()
    db.get = AsyncMock(return_value=None)
    db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.close = AsyncMock()
    return db


@pytest.fixture
def mock_db():
    return make_mock_db()


@pytest.fixture(autouse=True)
def _reset_rate_limits():
    from app.core.limiter import limiter

    limiter.reset()
    yield


@pytest.fixture(autouse=True)
def _reset_app_settings_cache():
    """Le cache des réglages en base (30 s, par processus) ne fuit pas d'un test à l'autre."""
    from app.services import app_settings

    app_settings.clear_cache()
    yield


@pytest.fixture
def default_anti_spam_limits(monkeypatch):
    """Faux lecteur des limites anti-spam (défauts .env), pour les tests dont le faux
    `db.get` renvoie le même objet quelle que soit la clé demandée."""
    from app.core.config import settings
    from app.services import app_settings

    async def _defaults(db):
        return settings.reload_count_max, settings.monthly_reloads_max

    monkeypatch.setattr(app_settings, "anti_spam_limits", _defaults)


@pytest.fixture(autouse=True)
def _reset_apns_service_singleton():
    """Reset le module-level `_service_instance` entre chaque test.

    Sans ce reset, les tests qui appellent `get_notification_service()` sans
    request/ctx polluent l'instance globale et provoquent un test-flake
    selon l'ordre d'exécution pytest (cf. Story 7.4 review P5).
    """
    from app.services.notifications import apns_service

    apns_service._service_instance = None
    yield
    apns_service._service_instance = None


@pytest.fixture
def fake_arq():
    """Faux pool ARQ unique (chantier 5 § 3), injecté via `app.dependency_overrides[get_arq]`."""
    return make_fake_arq()


@pytest.fixture
async def client(mock_db, fake_arq):
    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_get_db
    override_arq(fake_arq)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


# ── Magasin de révocation des jetons (chantier 2) ─────────────────────────────

TEST_REDIS_URL = os.environ.get("TEST_REDIS_URL", "redis://127.0.0.1:56379/0")
# Port fermé : sans Redis réel, le magasin « laisse passer » (warning), comme en prod.
_CLOSED_REDIS_URL = "redis://127.0.0.1:1/0"


@pytest.fixture(autouse=True)
async def _token_store_offline():
    """Par défaut, le magasin de révocation pointe sur un port fermé : les tests
    unitaires n'écrivent jamais dans un Redis de dev et vérifient le fail-open."""
    from redis.asyncio import Redis

    from app.core import token_store

    client = Redis.from_url(_CLOSED_REDIS_URL, socket_connect_timeout=0.2, socket_timeout=0.2)
    token_store.set_client_for_tests(client)
    yield
    token_store.set_client_for_tests(None)
    await client.aclose()


@pytest.fixture
async def token_redis(_token_store_offline):
    """Redis réel (TEST_REDIS_URL) branché sur le magasin ; clés de révocation effacées après."""
    from redis.asyncio import Redis

    from app.core import token_store

    client = Redis.from_url(TEST_REDIS_URL, socket_connect_timeout=2)
    try:
        await client.ping()
    except Exception as exc:  # noqa: BLE001
        pytest.fail(f"Redis de test injoignable ({exc}). Lancer : docker compose -f docker-compose.test.yml up -d")
    token_store.set_client_for_tests(client)
    yield client
    for pattern in ("revoked:jti:*", "refresh:grace:*"):
        keys = [k async for k in client.scan_iter(match=pattern)]
        if keys:
            await client.delete(*keys)
    token_store.set_client_for_tests(None)
    await client.aclose()
