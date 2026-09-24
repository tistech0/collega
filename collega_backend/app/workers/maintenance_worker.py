"""Crons de maintenance des imports (chantier 1)."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from arq.constants import in_progress_key_prefix
from sqlalchemy import func, select

from app.core.database import async_session_factory
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.services.content.purge import active_pdf_names, purge_orphan_pdfs, purge_unreferenced_content
from app.services.jobs.job_failure import ACTIVE_JOB_STATUSES, fail_job

logger = logging.getLogger(__name__)

STALE_AFTER = timedelta(minutes=30)
STALE_MESSAGE = "Import bloqué : aucune progression depuis 30 min"


async def fail_stale_jobs(ctx: dict, *, session_factory=None, now: datetime | None = None) -> int:
    """Imports actifs sans progression depuis 30 min et que plus aucun worker ne
    traite (timeout ARQ, file perdue, relances épuisées) → échec. Sans cela, le
    collège resterait « import en cours » (409) jusqu'à un Stop manuel."""
    session_factory = session_factory or async_session_factory
    now = now or datetime.now(UTC)
    last_event = (
        select(func.max(GenerationJobEvent.created_at))
        .where(GenerationJobEvent.generation_job_id == GenerationJob.id)
        .correlate(GenerationJob)
        .scalar_subquery()
    )
    async with session_factory() as db:
        rows = (
            await db.execute(
                select(GenerationJob.id, GenerationJob.arq_job_id, GenerationJob.updated_at, last_event).where(
                    GenerationJob.status.in_(ACTIVE_JOB_STATUSES)
                )
            )
        ).all()
    redis = ctx.get("redis")
    failed = 0
    for job_id, arq_job_id, updated_at, last_event_at in rows:
        last_activity = max(t for t in (updated_at, last_event_at) if t is not None)
        if now - last_activity < STALE_AFTER:
            continue
        if redis is not None and arq_job_id and await redis.exists(in_progress_key_prefix + arq_job_id):
            continue  # un worker le traite encore (OCR très long d'une page, par ex.)
        if await fail_job(session_factory, job_id, STALE_MESSAGE, event="stale"):
            failed += 1
    if failed:
        logger.warning("%d import(s) bloqué(s) passé(s) en échec", failed)
    return failed


async def purge_content(ctx: dict, *, session_factory=None) -> None:
    """Nuit : contenu non référencé et PDF orphelins."""
    session_factory = session_factory or async_session_factory
    async with session_factory() as db:
        await purge_unreferenced_content(db)
        await db.commit()
        keep = await active_pdf_names(db)
    purge_orphan_pdfs(keep)
