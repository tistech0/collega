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


async def test_migration_019_downgrade_recreates_tester_feedbacks(pg_engine):
    """019 supprime tester_feedbacks ; le downgrade la recrée telle qu'en 005."""
    from sqlalchemy import inspect

    def _tables(sync_conn):
        return set(inspect(sync_conn).get_table_names())

    def _tester_schema(sync_conn):
        insp = inspect(sync_conn)
        return (
            {c["name"]: (str(c["type"]), c["nullable"]) for c in insp.get_columns("tester_feedbacks")},
            sorted(
                (fk["constrained_columns"][0], fk["referred_table"]) for fk in insp.get_foreign_keys("tester_feedbacks")
            ),
            sorted(i["name"] for i in insp.get_indexes("tester_feedbacks")),
            [u["name"] for u in insp.get_unique_constraints("tester_feedbacks")],
        )

    async with pg_engine.connect() as conn:
        assert "tester_feedbacks" not in await conn.run_sync(_tables)

    cfg = alembic_config()
    await asyncio.to_thread(command.downgrade, cfg, "018")
    async with pg_engine.connect() as conn:
        columns, fks, indexes, uniques = await conn.run_sync(_tester_schema)
    assert columns == {
        "id": ("UUID", False),
        "flash_card_id": ("UUID", False),
        "college_id": ("UUID", False),
        "tester_id": ("VARCHAR(100)", False),
        "is_pertinent": ("BOOLEAN", False),
        "created_at": ("TIMESTAMP", False),
    }
    assert fks == [("college_id", "colleges"), ("flash_card_id", "flash_cards")]
    assert "ix_tester_feedbacks_college_id" in indexes and "ix_tester_feedbacks_flash_card_id" in indexes
    assert uniques == ["uq_tester_feedbacks_card_tester"]

    await asyncio.to_thread(command.upgrade, cfg, "head")
    async with pg_engine.connect() as conn:
        assert "tester_feedbacks" not in await conn.run_sync(_tables)
