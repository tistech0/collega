"""Worker ARQ cron — supprime ocr_text 24h après génération (NFR9)."""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy import update as sql_update

from app.core.database import async_session_factory
from app.models.generation_job import GenerationJob
from app.models.item import Item

logger = logging.getLogger(__name__)


async def cleanup_ocr_text(ctx: dict) -> None:
    """Supprime ocr_text des items dont le job est terminé depuis > 24h (NFR9)."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    async with async_session_factory() as db:
        completed_jobs_subq = (
            select(GenerationJob.college_id)
            .where(GenerationJob.status == "generation_complete")
            .where(GenerationJob.updated_at < cutoff)
            .scalar_subquery()
        )
        # Exclude colleges with an active job (re-processing in progress)
        active_jobs_subq = (
            select(GenerationJob.college_id)
            .where(GenerationJob.status.in_(["pending", "processing", "ocr_complete"]))
            .scalar_subquery()
        )
        result = await db.execute(
            sql_update(Item)
            .where(Item.college_id.in_(completed_jobs_subq))
            .where(~Item.college_id.in_(active_jobs_subq))
            .where(Item.ocr_text.is_not(None))
            .values(ocr_text=None)
        )
        await db.commit()
        logger.info("Cleaned OCR text from %d items", result.rowcount)
