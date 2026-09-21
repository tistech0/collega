"""Worker ARQ cron — supprime ocr_text 24h après génération (NFR9),
reset défensif des quotas mensuels (Story 7.2 — AC #2) et purge des
uploads par morceaux orphelins (Story 7.11)."""
from __future__ import annotations

import logging
import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy import update as sql_update

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.time_utils import next_month_reset
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.services.upload.chunked_upload import ChunkedUploadStore

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


async def reset_monthly_reloads(ctx: dict) -> None:
    """Reset défensif des compteurs mensuels (cron quotidien) — Story 7.2 AC #2.

    Filet de sécurité au-dessus du reset lazy fait dans `colleges.py:import_college_pdf`.
    Met `monthly_reloads=0` et avance `monthly_reloads_reset_at` pour tous les users
    dont la fenêtre est échue depuis plus d'une heure.

    Le délai d'1h évite le double-reset en frontière de mois : un lazy reset à
    23:59:xx le 31 mars met `reset_at=Apr 1 00:00`, et le cron à `Apr 1 00:05`
    ne doit pas re-resetter ce user (sinon il gagne une fenêtre de quota gratuite).
    """
    now = datetime.now(timezone.utc)
    grace_period = timedelta(hours=1)
    async with async_session_factory() as db:
        result = await db.execute(
            sql_update(User)
            .where(User.monthly_reloads_reset_at.is_not(None))
            .where(User.monthly_reloads_reset_at <= now - grace_period)
            .values(
                monthly_reloads=0,
                monthly_reloads_reset_at=next_month_reset(now),
            )
        )
        await db.commit()
        logger.info("Reset monthly reloads for %d users", result.rowcount)


async def cleanup_stale_uploads(ctx: dict) -> int:
    """Supprime les dossiers uploads/{id} sans clé Redis (upload terminé/abandonné) ou > 24 h.
    Story 7.11 — filet de sécurité disque au-dessus du TTL Redis. Renvoie le nombre de dossiers purgés."""
    store = ChunkedUploadStore(ctx["redis"], Path(settings.pdf_storage_path))
    base = Path(settings.pdf_storage_path) / "uploads"
    if not base.exists():
        return 0
    stale = set(store.stale_dirs(timedelta(hours=24)))
    removed = 0
    for d in sorted(p for p in base.iterdir() if p.is_dir()):
        if d in stale or await store.get(d.name) is None:
            shutil.rmtree(d, ignore_errors=True)
            removed += 1
    logger.info("Purged %d stale chunked uploads", removed)
    return removed
