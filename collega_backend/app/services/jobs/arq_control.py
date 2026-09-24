"""Contrôle best-effort des jobs ARQ (annulation) — Story 7.7.

Isole l'interaction Redis/ARQ derrière une fonction unique pour la rendre
mockable dans les tests de l'endpoint Stop (jamais de vrai Redis en test).
"""

from __future__ import annotations

import contextlib
import logging

logger = logging.getLogger(__name__)


async def abort_arq_job(arq_job_id: str, *, timeout: float = 5.0) -> bool:
    """Demande l'annulation d'un job ARQ via l'abort set Redis (best-effort).

    Ajoute le job à l'abort set et attend son résultat jusqu'à `timeout`.
    L'abort n'est honoré que si le worker tourne avec `allow_abort_jobs=True`.
    Retourne True si l'abort a été confirmé, False sinon (job déjà terminé,
    timeout, Redis indisponible…). N'élève jamais : l'endpoint force le statut
    DB indépendamment du résultat.
    """
    pool = None
    try:
        from arq import create_pool  # type: ignore[import]
        from arq.jobs import Job  # type: ignore[import]

        from app.core.redis import redis_settings

        pool = await create_pool(redis_settings)
        job = Job(job_id=arq_job_id, redis=pool)
        return await job.abort(timeout=timeout)
    except Exception as exc:  # noqa: BLE001 — best-effort, l'endpoint reste seul garant du statut DB
        logger.warning("abort_arq_job failed for %s: %s", arq_job_id, exc)
        return False
    finally:
        if pool is not None:
            with contextlib.suppress(Exception):  # cleanup non bloquant
                await pool.close()
