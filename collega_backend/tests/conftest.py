"""Configuration pytest commune.

Utilise SQLite (aiosqlite) en tests pour éviter asyncpg et PostgreSQL.
Les dépendances DB et ARQ sont mockées via override FastAPI.
"""
import os

# Doit être défini AVANT l'import du module settings (module-level Settings())
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./test.db")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("RATE_LIMIT_STORAGE_URI", "memory://")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-pytest-only")
os.environ.setdefault("CLAUDE_API_KEY", "test-key")
os.environ.setdefault("ADMIN_USERNAME", "admin")
os.environ.setdefault("ADMIN_PASSWORD", "testpass")
os.environ.setdefault("REVENUECAT_WEBHOOK_SECRET", "test-rc-secret")
os.environ.setdefault("TESTER_USERNAME", "tester")
os.environ.setdefault("TESTER_PASSWORD", "testpass")

from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient


# Override de create_async_engine pour SQLite (sans pool_size / max_overflow)
import sqlalchemy.ext.asyncio as _sa_async

_orig_create = _sa_async.create_async_engine


def _patched_create_engine(url, **kwargs):
    # Supprimer les options non supportées par SQLite
    kwargs.pop("pool_size", None)
    kwargs.pop("max_overflow", None)
    return _orig_create(url, **kwargs)


_sa_async.create_async_engine = _patched_create_engine  # type: ignore[assignment]

from app.core.database import get_db
from app.main import app

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
async def client(mock_db):
    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
