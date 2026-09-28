"""scripts/import_alerts.py : imports passés en échec depuis le dernier passage."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import text, update

from app.models.generation_job import GenerationJob
from app.services import app_settings
from scripts.import_alerts import KEY, collect
from tests.factories import make_college, make_job, make_user

pytestmark = pytest.mark.pg


async def _failed_job(db, ref_id: int, at: datetime, message: str | None = "OCR illisible"):
    user = await make_user(db)
    job = await make_job(db, await make_college(db, user, ref_id=ref_id), status="failed")
    # `updated_at` est aussi forcé à now() par un trigger Postgres BEFORE UPDATE
    # (migration 003, `update_generation_jobs_updated_at`) : un simple UPDATE ORM
    # ou SQL se le fait écraser. Le désactiver le temps de fixer la valeur passée
    # (voir tests/api/test_admin_pilot_pg.py pour le même motif).
    await db.execute(text("ALTER TABLE generation_jobs DISABLE TRIGGER update_generation_jobs_updated_at"))
    await db.execute(
        update(GenerationJob).where(GenerationJob.id == job.id).values(updated_at=at, error_message=message)
    )
    await db.execute(text("ALTER TABLE generation_jobs ENABLE TRIGGER update_generation_jobs_updated_at"))
    return user


async def test_premier_passage_silencieux(pg_session):
    now = datetime.now(UTC)
    await _failed_job(pg_session, 4, now - timedelta(hours=1))
    assert await collect(pg_session, now) == []
    app_settings.clear_cache()
    assert await app_settings.get_setting(pg_session, KEY, None) == now.isoformat()


async def test_nouveaux_echecs_puis_rien(pg_session):
    now = datetime.now(UTC)
    await app_settings.set_setting(pg_session, KEY, (now - timedelta(minutes=5)).isoformat())
    user = await _failed_job(pg_session, 4, now - timedelta(minutes=1))
    await _failed_job(pg_session, 999, now - timedelta(seconds=30), message=None)
    await _failed_job(pg_session, 5, now - timedelta(minutes=10))  # avant le point de reprise

    lines = await collect(pg_session, now)
    assert lines == [f"Cardiologie — {user.email} : OCR illisible", lines[1]]
    assert lines[1].startswith("Collège n°999 — ") and lines[1].endswith(": erreur inconnue")
    app_settings.clear_cache()
    assert await collect(pg_session, now + timedelta(minutes=1)) == []


async def test_message_long_tronque(pg_session):
    now = datetime.now(UTC)
    await app_settings.set_setting(pg_session, KEY, (now - timedelta(minutes=5)).isoformat())
    await _failed_job(pg_session, 4, now - timedelta(minutes=1), message="x" * 500)
    [line] = await collect(pg_session, now)
    assert len(line) < 260 and line.endswith("…")
