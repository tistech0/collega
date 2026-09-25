"""record_usage : une ligne claude_usage par appel facturé, en session courte (chantier 4, spec § 6)."""

import logging

import pytest
from sqlalchemy import select

from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.services.generation import usage as usage_module
from app.services.generation.usage import record_usage
from tests.factories import make_college, make_job, make_user

pytestmark = pytest.mark.pg


async def test_writes_one_row(pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user)
        job = await make_job(db, college)
        await db.commit()

    await record_usage(
        pg_factory,
        kind="generation",
        model="claude-sonnet-5",
        input_tokens=1200,
        output_tokens=300,
        user_id=user.id,
        college_id=college.id,
        job_id=job.id,
    )

    async with pg_factory() as s:
        row = (await s.execute(select(ClaudeUsage))).scalar_one()
    assert (row.kind, row.model, row.input_tokens, row.output_tokens) == ("generation", "claude-sonnet-5", 1200, 300)
    assert (row.user_id, row.college_id, row.job_id) == (user.id, college.id, job.id)
    assert row.created_at is not None


async def test_deleted_college_and_job_are_recorded_as_null(pg_factory):
    """Collège supprimé pendant l'appel : l'appel reste compté, sans lien."""
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user)
        job = await make_job(db, college)
        await db.commit()
    async with pg_factory() as db:
        await db.delete(await db.get(College, college.id))
        await db.commit()

    await record_usage(
        pg_factory,
        kind="generation",
        model="claude-sonnet-5",
        input_tokens=10,
        output_tokens=1,
        user_id=user.id,
        college_id=college.id,
        job_id=job.id,
    )

    async with pg_factory() as s:
        row = (await s.execute(select(ClaudeUsage))).scalar_one()
    assert (row.user_id, row.college_id, row.job_id) == (user.id, None, None)


async def test_db_error_is_logged_never_raised(caplog):
    class Broken:
        def __call__(self):
            raise OSError("base injoignable")

    with caplog.at_level(logging.WARNING, logger=usage_module.__name__):
        await record_usage(
            Broken(),  # type: ignore[arg-type]
            kind="evaluation",
            model="claude-haiku-4-5-20251001",
            input_tokens=80,
            output_tokens=15,
            user_id=None,
        )
    assert any("evaluation" in r.getMessage() for r in caplog.records)
