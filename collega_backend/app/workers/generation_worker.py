"""Worker ARQ pour la génération de flashcards via Claude API ou hash-sharing."""
from __future__ import annotations

import logging
import uuid

from app.core.database import async_session_factory
from app.models.generation_job import GenerationJob
from app.services.generation.card_generator import CardGenerator

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
            card_generator = CardGenerator()
            result = await card_generator.generate_for_college(
                db, uuid.UUID(college_id), uuid.UUID(job_id), pdf_path
            )
            return result
        except Exception as exc:
            logger.exception("Generation failed for college %s: %s", college_id, exc)
            await db.rollback()
            job = await db.get(GenerationJob, uuid.UUID(job_id))
            if job is not None:
                job.status = "failed"
                job.error_message = str(exc)
                try:
                    await db.commit()
                except Exception:
                    logger.error("Failed to persist failure status for job %s", job_id)
            raise
