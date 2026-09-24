"""Migration 021, partie claude_usage : reprise de l'historique des jobs puis suppression
des colonnes generation_jobs.input_tokens/output_tokens ; downgrade complet."""

import asyncio
import uuid
from datetime import UTC, datetime

import pytest
from sqlalchemy import inspect, text

from alembic import command
from tests.pg import alembic_config

pytestmark = pytest.mark.pg

_CREATED = datetime(2026, 6, 1, 12, 0, tzinfo=UTC)


def _job_columns(sync_conn) -> set[str]:
    return {c["name"] for c in inspect(sync_conn).get_columns("generation_jobs")}


async def _seed_020(conn) -> tuple[uuid.UUID, uuid.UUID, uuid.UUID, uuid.UUID]:
    user_id, college_id = uuid.uuid4(), uuid.uuid4()
    measured, unmeasured = uuid.uuid4(), uuid.uuid4()
    await conn.execute(
        text("INSERT INTO users (id, email, hashed_password, created_at) VALUES (:id, 'u@test.fr', 'x', now())"),
        {"id": user_id},
    )
    await conn.execute(
        text(
            "INSERT INTO colleges (id, user_id, college_ref_id, status, created_at, updated_at) "
            "VALUES (:id, :u, 34, 'generation_complete', now(), now())"
        ),
        {"id": college_id, "u": user_id},
    )
    for job_id, tokens in ((measured, (1000, 200)), (unmeasured, (None, None))):
        await conn.execute(
            text(
                "INSERT INTO generation_jobs (id, college_id, user_id, status, created_at, updated_at, "
                "input_tokens, output_tokens) VALUES (:id, :c, :u, 'generation_complete', :t, now(), :i, :o)"
            ),
            {"id": job_id, "c": college_id, "u": user_id, "t": _CREATED, "i": tokens[0], "o": tokens[1]},
        )
    return user_id, college_id, measured, unmeasured


async def test_history_moved_to_claude_usage_and_columns_dropped(pg_engine):
    cfg = alembic_config()
    await asyncio.to_thread(command.downgrade, cfg, "020")
    async with pg_engine.begin() as conn:
        user_id, college_id, measured, _ = await _seed_020(conn)

    await asyncio.to_thread(command.upgrade, cfg, "head")
    async with pg_engine.connect() as conn:
        rows = (
            await conn.execute(
                text(
                    "SELECT user_id, college_id, job_id, kind, model, input_tokens, output_tokens, created_at "
                    "FROM claude_usage"
                )
            )
        ).all()
        columns = await conn.run_sync(_job_columns)
    assert rows == [(user_id, college_id, measured, "generation", "claude-sonnet-4-6", 1000, 200, _CREATED)]
    assert "input_tokens" not in columns and "output_tokens" not in columns

    # Downgrade : colonnes recréées et remplies depuis claude_usage, table supprimée.
    await asyncio.to_thread(command.downgrade, cfg, "020")
    async with pg_engine.connect() as conn:
        tokens = (
            await conn.execute(
                text("SELECT input_tokens, output_tokens FROM generation_jobs WHERE id = :id"), {"id": measured}
            )
        ).one()
        tables = await conn.run_sync(lambda c: set(inspect(c).get_table_names()))
    assert tuple(tokens) == (1000, 200)
    assert "claude_usage" not in tables
    await asyncio.to_thread(command.upgrade, cfg, "head")


async def test_claude_usage_schema(pg_engine):
    def _schema(sync_conn):
        insp = inspect(sync_conn)
        return (
            {c["name"]: (str(c["type"]), c["nullable"]) for c in insp.get_columns("claude_usage")},
            sorted(
                (fk["constrained_columns"][0], fk["referred_table"], fk["options"].get("ondelete"))
                for fk in insp.get_foreign_keys("claude_usage")
            ),
            sorted((i["name"], tuple(i["column_names"])) for i in insp.get_indexes("claude_usage")),
            [c["sqltext"] for c in insp.get_check_constraints("claude_usage")],
        )

    async with pg_engine.connect() as conn:
        columns, fks, indexes, checks = await conn.run_sync(_schema)
    assert columns == {
        "id": ("UUID", False),
        "created_at": ("TIMESTAMP", False),
        "user_id": ("UUID", True),
        "college_id": ("UUID", True),
        "job_id": ("UUID", True),
        "kind": ("TEXT", False),
        "model": ("TEXT", False),
        "input_tokens": ("INTEGER", False),
        "output_tokens": ("INTEGER", False),
    }
    assert fks == [
        ("college_id", "colleges", "SET NULL"),
        ("job_id", "generation_jobs", "SET NULL"),
        ("user_id", "users", "SET NULL"),
    ]
    assert indexes == [
        ("ix_claude_usage_job_id", ("job_id",)),
        ("ix_claude_usage_user_id_created_at", ("user_id", "created_at")),
    ]
    assert len(checks) == 1 and all(k in checks[0] for k in ("generation", "regeneration", "evaluation"))
