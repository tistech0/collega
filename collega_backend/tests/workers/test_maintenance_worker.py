"""Cron des imports bloqués (chantier 1), Postgres réel."""
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select, text, update

from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.workers.maintenance_worker import fail_stale_jobs
from tests.factories import make_college, make_job, make_user
from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401

pytestmark = pytest.mark.pg


class Redis:
    def __init__(self, in_progress=()):
        self.keys = {f"arq:in-progress:{k}" for k in in_progress}

    async def exists(self, key):
        return int(key in self.keys)


async def _job(pg_factory, *, minutes_ago: int, status="processing", arq_job_id="arq-1"):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete")
        job = await make_job(db, college, status=status)
        job.arq_job_id = arq_job_id
        past = datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)
        db.add(GenerationJobEvent(generation_job_id=job.id, event_type="ocr_progress", created_at=past))
        await db.commit()
        # Un trigger remet updated_at à NOW() à chaque UPDATE : désactivé le temps de
        # vieillir le job (c'est ce trigger qui fait de toute écriture une « progression »).
        await db.execute(text("ALTER TABLE generation_jobs DISABLE TRIGGER USER"))
        await db.execute(update(GenerationJob).where(GenerationJob.id == job.id).values(updated_at=past))
        await db.execute(text("ALTER TABLE generation_jobs ENABLE TRIGGER USER"))
        await db.commit()
        return job.id


async def _status(pg_factory, job_id):
    async with pg_factory() as s:
        return (await s.get(GenerationJob, job_id)).status


async def test_stale_job_is_failed_with_stale_event(pg_factory):
    job_id = await _job(pg_factory, minutes_ago=31)
    assert await fail_stale_jobs({"redis": Redis()}, session_factory=pg_factory) == 1
    assert await _status(pg_factory, job_id) == "failed"
    async with pg_factory() as s:
        events = (await s.execute(
            select(GenerationJobEvent.event_type).where(GenerationJobEvent.generation_job_id == job_id)
        )).scalars().all()
    assert "stale" in events


async def test_recent_activity_is_left_alone(pg_factory):
    job_id = await _job(pg_factory, minutes_ago=5)
    assert await fail_stale_jobs({"redis": Redis()}, session_factory=pg_factory) == 0
    assert await _status(pg_factory, job_id) == "processing"


async def test_job_still_running_in_arq_is_left_alone(pg_factory):
    job_id = await _job(pg_factory, minutes_ago=45)
    assert await fail_stale_jobs({"redis": Redis(in_progress={"arq-1"})}, session_factory=pg_factory) == 0
    assert await _status(pg_factory, job_id) == "processing"


async def test_finished_jobs_are_ignored(pg_factory):
    job_id = await _job(pg_factory, minutes_ago=600, status="generation_complete")
    assert await fail_stale_jobs({"redis": Redis()}, session_factory=pg_factory) == 0
    assert await _status(pg_factory, job_id) == "generation_complete"

