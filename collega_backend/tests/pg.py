"""Postgres réel pour les tests du pipeline d'import (chantier 1).

Lancer d'abord : docker compose -f docker-compose.test.yml up -d
Chaque test part d'un schéma neuf migré par Alembic (`upgrade head`), donc les
index et contraintes réels (index unique partiel, FK, cascades) sont en place.
Sans serveur, les tests « pg » échouent (jamais ignorés en silence).
"""

from __future__ import annotations

import asyncio
import os
from collections.abc import AsyncIterator

import pytest
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from alembic import command

TEST_PG_URL = os.environ.get("TEST_PG_URL", "postgresql+asyncpg://postgres:postgres@127.0.0.1:55432/collega_test")
_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def alembic_config(url: str = TEST_PG_URL) -> Config:
    cfg = Config(os.path.join(_BACKEND_DIR, "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(_BACKEND_DIR, "alembic"))
    cfg.attributes["test_url"] = url
    return cfg


async def _reset_schema() -> None:
    engine = create_async_engine(TEST_PG_URL)
    try:
        async with engine.begin() as conn:
            await conn.execute(text("DROP SCHEMA public CASCADE"))
            await conn.execute(text("CREATE SCHEMA public"))
    except OSError as exc:  # connexion refusée
        pytest.fail(f"Postgres de test injoignable ({exc}). Lancer : docker compose -f docker-compose.test.yml up -d")
    finally:
        await engine.dispose()


@pytest.fixture
async def pg_engine() -> AsyncIterator[AsyncEngine]:
    await _reset_schema()
    await asyncio.to_thread(command.upgrade, alembic_config(), "head")
    engine = create_async_engine(TEST_PG_URL)
    yield engine
    await engine.dispose()


@pytest.fixture
def pg_factory(pg_engine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(pg_engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture
async def pg_session(pg_factory) -> AsyncIterator[AsyncSession]:
    async with pg_factory() as session:
        yield session
