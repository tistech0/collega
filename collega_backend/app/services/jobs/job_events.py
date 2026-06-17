"""Écriture défensive d'événements de timeline pour un GenerationJob (Story 7.7).

`record_job_event` fait UNIQUEMENT `db.add(...)` (sans commit) : les events sont
persistés par les `await db.commit()` déjà présents dans le pipeline (boucle OCR,
transitions de statut). Le helper est enveloppé dans un try/except large et
**n'élève jamais** — un échec d'écriture d'event ne doit jamais casser l'OCR ou
la génération (exigence AC1).
"""
from __future__ import annotations

import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.generation_job_event import GenerationJobEvent

logger = logging.getLogger(__name__)


async def record_job_event(
    db: AsyncSession,
    generation_job_id: uuid.UUID,
    event_type: str,
    *,
    message: str | None = None,
    page: int | None = None,
    total: int | None = None,
) -> None:
    """Ajoute un GenerationJobEvent à la session (sans commit).

    Le commit est porté par le flux appelant. Toute exception est avalée et
    journalisée en warning — la timeline est best-effort, jamais bloquante.
    """
    try:
        db.add(
            GenerationJobEvent(
                generation_job_id=generation_job_id,
                event_type=event_type,
                message=message,
                page=page,
                total=total,
            )
        )
    except Exception as exc:  # noqa: BLE001 — best-effort, ne jamais casser le pipeline
        logger.warning(
            "record_job_event failed (job=%s, type=%s): %s",
            generation_job_id,
            event_type,
            exc,
        )
