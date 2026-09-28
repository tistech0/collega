"""Suppression d'un compte : partagée par l'utilisatrice (DELETE /v1/auth/account) et
la console admin (DELETE /v1/admin/users/{id})."""

from __future__ import annotations

import logging
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.services.content.purge import delete_college_pdfs, purge_unreferenced_content
from app.services.imports import ACTIVE_JOB_STATUSES

logger = logging.getLogger(__name__)


async def has_active_job(db: AsyncSession, user_id: uuid.UUID) -> bool:
    result = await db.execute(
        select(GenerationJob.id)
        .where(GenerationJob.user_id == user_id, GenerationJob.status.in_(ACTIVE_JOB_STATUSES))
        .limit(1)
    )
    return result.first() is not None


async def delete_account(db: AsyncSession, user: User) -> None:
    """Supprime le compte et tout ce qui en dépend (cascade), puis ses PDF et le contenu
    qui n'appartenait qu'à lui. Le nettoyage est best-effort : le compte est déjà
    supprimé, le cron de nuit rattrape un échec."""
    college_ids = list((await db.execute(select(College.id).where(College.user_id == user.id))).scalars())
    await db.delete(user)
    await db.commit()
    for college_id in college_ids:
        delete_college_pdfs(college_id)
    try:
        await purge_unreferenced_content(db)
        await db.commit()
    except Exception:  # noqa: BLE001
        logger.warning("Purge du contenu après suppression de compte reportée au cron", exc_info=True)
