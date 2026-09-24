"""Worker ARQ cron — reset défensif des quotas mensuels (Story 7.2 — AC #2) et
purge des uploads par morceaux orphelins (Story 7.11). La purge du texte OCR à
24 h (NFR9) est supprimée au chantier 1 : le texte est conservé avec le collège."""

from __future__ import annotations

import logging
import shutil
from datetime import UTC, datetime, timedelta
from pathlib import Path

from sqlalchemy import update as sql_update

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.time_utils import next_month_reset
from app.models.user import User
from app.services.upload.chunked_upload import ChunkedUploadStore

logger = logging.getLogger(__name__)


async def reset_monthly_reloads(ctx: dict) -> None:
    """Reset défensif des compteurs mensuels (cron quotidien) — Story 7.2 AC #2.

    Filet de sécurité au-dessus du reset lazy fait dans `colleges.py:import_college_pdf`.
    Met `monthly_reloads=0` et avance `monthly_reloads_reset_at` pour tous les users
    dont la fenêtre est échue depuis plus d'une heure.

    Le délai d'1h évite le double-reset en frontière de mois : un lazy reset à
    23:59:xx le 31 mars met `reset_at=Apr 1 00:00`, et le cron à `Apr 1 00:05`
    ne doit pas re-resetter ce user (sinon il gagne une fenêtre de quota gratuite).
    """
    now = datetime.now(UTC)
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
