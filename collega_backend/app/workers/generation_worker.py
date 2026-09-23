"""Worker ARQ pour la génération de flashcards via Claude API ou hash-sharing."""
from __future__ import annotations

import logging
import uuid

from app.core.database import async_session_factory
from app.models.generation_job import GenerationJob
from app.services.generation.card_generator import CardGenerator, report_generation_progress
from app.services.jobs.job_events import record_job_event

logger = logging.getLogger(__name__)


async def generate_college_cards(
    ctx: dict,
    college_id: str,
    job_id: str,
    pdf_path: str,
) -> dict:
    """Génère les fiches d'un college via Claude ou hash-sharing."""
    async with async_session_factory() as db:
        job = await db.get(GenerationJob, uuid.UUID(job_id))
        if job is None or job.status != "ocr_complete":
            logger.info(
                "Job %s not in ocr_complete state (status=%s) — skipping (likely ARQ retry after failure)",
                job_id,
                job.status if job else "not found",
            )
            return {"error": "invalid_job_state"}

        try:
            card_generator = CardGenerator(progress_reporter=report_generation_progress)
            result = await card_generator.generate_for_college(
                db, uuid.UUID(college_id), uuid.UUID(job_id), pdf_path
            )

            # Envoyer notification push (erreur APNs ne fait PAS échouer le job)
            try:
                from sqlalchemy import select

                from app.models.college import College
                from app.models.user import User
                from app.services.notifications.apns_service import get_notification_service

                # P16: lire user_id depuis l'ORM avant d'ouvrir une nouvelle session
                user_id_for_notif = job.user_id

                async with async_session_factory() as notif_db:
                    user_result = await notif_db.execute(
                        select(User).where(User.id == user_id_for_notif)
                    )
                    user = user_result.scalar_one_or_none()
                    college_result = await notif_db.execute(
                        select(College).where(College.id == uuid.UUID(college_id))
                    )
                    college = college_result.scalar_one_or_none()
                    if user and college:
                        await get_notification_service(ctx=ctx).send_generation_complete(
                            user.apns_token, college.college_ref_id
                        )
            except Exception as notif_exc:
                logger.warning("Notification push ignorée (non-bloquant) : %s", notif_exc)

            return result
        except Exception as exc:
            logger.exception("Generation failed for college %s: %s", college_id, exc)
            await db.rollback()
            job = await db.get(GenerationJob, uuid.UUID(job_id))
            if job is not None:
                job.status = "failed"
                job.error_message = str(exc)
                await record_job_event(db, job.id, "failed", message=str(exc))
                try:
                    await db.commit()
                except Exception:
                    logger.error("Failed to persist failure status for job %s", job_id)
            raise
