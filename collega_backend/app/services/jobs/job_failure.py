"""Échec d'un import — un seul chemin pour les workers, le Stop admin et le cron
des jobs bloqués (chantier 1).

Toujours dans une session neuve : celle de l'appelant peut être inutilisable
(rollback en attente, connexion perdue, CancelledError du timeout ARQ).
Le contenu en service du collège n'est jamais touché : un réimport qui échoue
laisse le collège `generation_complete` et son quota est rendu (l'utilisatrice
n'a rien obtenu) ; seul un premier import passe le collège à `failed`.
Verrous dans le même ordre que la bascule (collège puis job) : pas d'interblocage.
"""
from __future__ import annotations

import logging
import uuid
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import settings
from app.models.college import College, CollegeStatus
from app.models.content import JobItem, JobPage
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.services.jobs.job_events import record_job_event
from app.services.notifications.apns_service import get_notification_service

logger = logging.getLogger(__name__)

ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")


async def fail_job(
    session_factory: async_sessionmaker[AsyncSession],
    job_id: uuid.UUID,
    message: str,
    *,
    event: str = "failed",
    notify: bool = True,
) -> bool:
    """Passe un import actif en `failed`. Renvoie False s'il n'existe plus ou
    n'était plus actif (déjà terminé, déjà en échec) — rien n'est alors modifié."""
    async with session_factory() as db:
        college_id = (
            await db.execute(select(GenerationJob.college_id).where(GenerationJob.id == job_id))
        ).scalar_one_or_none()
        if college_id is None:
            return False
        college = (
            await db.execute(select(College).where(College.id == college_id).with_for_update())
        ).scalar_one_or_none()
        job = (
            await db.execute(select(GenerationJob).where(GenerationJob.id == job_id).with_for_update())
        ).scalar_one_or_none()
        if job is None or job.status not in ACTIVE_JOB_STATUSES:
            return False
        user = await db.get(User, job.user_id)
        reimport = college is not None and college.status == CollegeStatus.generation_complete
        ref_id = college.college_ref_id if college is not None else None
        token = user.apns_token if user is not None else None

        job.status = "failed"
        job.error_message = message
        await record_job_event(db, job.id, event, message=message)
        await db.execute(delete(JobPage).where(JobPage.job_id == job.id))
        await db.execute(delete(JobItem).where(JobItem.job_id == job.id))
        if college is not None:
            college.generation_items_total = None
            if not reimport:
                college.status = CollegeStatus.failed
            else:
                # Réimport sans résultat : le quota consommé au router est rendu
                # (UPDATE conditionnels : jamais négatif).
                await db.execute(
                    sa_update(College).where(College.id == college.id).where(College.reload_count > 0)
                    .values(reload_count=College.reload_count - 1)
                )
                await db.execute(
                    sa_update(User).where(User.id == job.user_id).where(User.monthly_reloads > 0)
                    .values(monthly_reloads=User.monthly_reloads - 1)
                )
        await db.commit()

    # Le PDF d'un import échoué n'est jamais le PDF en service (celui du dernier
    # import réussi) : on le supprime.
    try:
        Path(settings.pdf_storage_path, f"{college_id}_{job_id}.pdf").unlink(missing_ok=True)
    except OSError:
        logger.warning("PDF de l'import %s non supprimé", job_id, exc_info=True)

    if notify and ref_id is not None:
        try:
            await get_notification_service().send_import_failed(token, ref_id, reimport)
        except Exception:  # noqa: BLE001 — une notification ne fait jamais échouer
            logger.warning("Notification d'échec non envoyée (job %s)", job_id, exc_info=True)
    logger.info("Import %s en échec (%s) : %s", job_id, event, message)
    return True
