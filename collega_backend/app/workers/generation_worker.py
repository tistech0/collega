"""Worker ARQ : génération des fiches d'un import puis bascule (chantier 1)."""

from __future__ import annotations

import logging
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.database import async_session_factory
from app.models.claude_usage import ClaudeUsage
from app.models.college import College, CollegeStatus
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.services.generation.claude_client import ClaudeClient
from app.services.generation.pipeline import generate_job_items, report_generation_progress
from app.services.generation.publish import ImportRejected, publish_job, stale_pdfs
from app.services.jobs.job_events import record_job_event
from app.services.jobs.job_failure import fail_job
from app.services.notifications.apns_service import get_notification_service

logger = logging.getLogger(__name__)


async def generate_college_cards(ctx: dict, college_id: str, job_id: str, pdf_path: str) -> dict:
    """Tâche ARQ. Une erreur passe l'import en échec (contenu en service intact,
    générations déjà obtenues réutilisables). Une interruption (CancelledError :
    redéploiement, arrêt du worker) le laisse actif : ARQ le reprend au redémarrage
    sans repayer les items déjà générés ; jamais repris → cron des jobs bloqués."""
    job_uuid = uuid.UUID(job_id)
    try:
        return await run_generation(async_session_factory, uuid.UUID(college_id), job_uuid, ClaudeClient(), ctx=ctx)
    except Exception as exc:
        logger.exception("Generation failed for college %s: %r", college_id, exc)
        await fail_job(async_session_factory, job_uuid, f"Génération : {exc!r}"[:500])
        raise


async def run_generation(
    session_factory: async_sessionmaker[AsyncSession],
    college_id: uuid.UUID,
    job_id: uuid.UUID,
    claude,
    *,
    ctx: dict | None = None,
    progress=report_generation_progress,
) -> dict:
    base = {"college_id": str(college_id), "job_id": str(job_id)}
    async with session_factory() as db:
        job = await db.get(GenerationJob, job_id)
        if job is None or job.status != "ocr_complete":
            logger.info("Génération du job %s ignorée (état %s)", job_id, job.status if job else "absent")
            return {**base, "error": "invalid_job_state"}
        await record_job_event(db, job_id, "generation_started")
        await db.commit()

    calls = await generate_job_items(session_factory, job_id, claude, progress)
    if calls is None:
        return {**base, "error": "cancelled"}

    async with session_factory() as db:
        college = await db.get(College, college_id)
        job = await db.get(GenerationJob, job_id)
        if college is None or job is None:
            return {**base, "error": "cancelled"}
        was_ready = college.status == CollegeStatus.generation_complete
        # Une relance ARQ ne compte que ses propres appels : le job a-t-il consommé
        # des tokens (tentatives précédentes comprises) ? C'est ce qui décide du quota.
        billed = (
            await db.execute(select(ClaudeUsage.id).where(ClaudeUsage.job_id == job_id).limit(1))
        ).first() is not None
        total_calls = max(calls, 1) if billed else calls
        try:
            summary = await publish_job(db, job_id, claude_calls=total_calls)
        except ImportRejected as rejected:
            # Mauvais PDF probable : rien n'est modifié, l'import est refusé (quota rendu).
            await db.rollback()
            await fail_job(session_factory, job_id, str(rejected))
            return {**base, "error": "rejected", "message": str(rejected)}
        if summary is None:
            return {**base, "error": "invalid_job_state"}
        user = await db.get(User, job.user_id)
        token, ref_id = (user.apns_token if user else None), college.college_ref_id
        await db.commit()

    for path in stale_pdfs(college_id, job_id):
        try:
            path.unlink(missing_ok=True)
        except OSError:
            logger.warning("Ancien PDF non supprimé : %s", path, exc_info=True)

    try:
        await get_notification_service(ctx=ctx).send_generation_complete(
            token, ref_id, summary.as_dict() if was_ready else None
        )
    except Exception:  # noqa: BLE001 — une notification ne fait jamais échouer l'import
        logger.warning("Notification de fin d'import non envoyée (job %s)", job_id, exc_info=True)

    return {**base, **summary.as_dict()}
