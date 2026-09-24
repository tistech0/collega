"""`alembic check` : les modèles déclarent exactement le schéma produit par les migrations."""

import asyncio

import pytest
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext

import app.models  # noqa: F401
from alembic import command
from app.core.database import Base, alembic_include_object
from tests.pg import alembic_config

pytestmark = pytest.mark.pg


async def test_models_match_migrations(pg_engine):
    async with pg_engine.connect() as conn:
        diff = await conn.run_sync(
            lambda sync_conn: compare_metadata(
                MigrationContext.configure(sync_conn, opts={"include_object": alembic_include_object}),
                Base.metadata,
            )
        )
    assert diff == []


async def test_migration_018_downgrade_then_upgrade(pg_engine):
    cfg = alembic_config()
    await asyncio.to_thread(command.downgrade, cfg, "017")
    await asyncio.to_thread(command.upgrade, cfg, "head")
