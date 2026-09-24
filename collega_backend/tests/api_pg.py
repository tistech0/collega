"""Client API branché sur le Postgres de test (chantier 1)."""

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient

ADMIN_AUTH = ("admin", "testpass")


@pytest.fixture
async def pg_client(pg_factory, monkeypatch) -> AsyncIterator[AsyncClient]:
    """Toutes les sessions de l'app (dépendance get_db et sessions courtes des
    routes, workers et services) pointent sur la base de test."""
    import app.core.database as database
    from app.api.v1 import admin as admin_module
    from app.api.v1 import colleges as colleges_module
    from app.core.database import get_db
    from app.main import app

    async def override_get_db():
        async with pg_factory() as session:
            yield session

    for module in (database, colleges_module, admin_module):
        monkeypatch.setattr(module, "async_session_factory", pg_factory)
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()


def login_as(user) -> None:
    """Authentifie les requêtes suivantes comme `user` (routes normales et flux SSE)."""
    from app.deps import get_current_user, get_current_user_short_session
    from app.main import app

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_current_user_short_session] = lambda: user
