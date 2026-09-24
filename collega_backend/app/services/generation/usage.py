"""Comptabilité des tokens Claude (chantier 4, spec § 6) : une ligne `claude_usage`
par appel facturé, écrite juste après la réponse, dans sa propre session courte.

Jamais bloquant : une erreur de base est journalisée (sans texte de fiche) et la
requête ou le job continue.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any, Literal

from sqlalchemy import ScalarSelect, insert, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.user import User

logger = logging.getLogger(__name__)

UsageKind = Literal["generation", "regeneration", "evaluation"]


def _if_exists(column: Any, value: uuid.UUID | None) -> ScalarSelect[Any] | None:
    """Le lien s'il existe encore, NULL sinon : un compte, collège ou job supprimé
    pendant l'appel ne fait pas perdre la ligne (violation de clé étrangère)."""
    if value is None:
        return None
    return select(column).where(column == value).scalar_subquery()


async def record_usage(
    session_factory: async_sessionmaker[AsyncSession],
    *,
    kind: UsageKind,
    model: str,
    input_tokens: int,
    output_tokens: int,
    user_id: uuid.UUID | None,
    college_id: uuid.UUID | None = None,
    job_id: uuid.UUID | None = None,
) -> None:
    try:
        async with session_factory() as session:
            await session.execute(
                insert(ClaudeUsage).values(
                    id=uuid.uuid4(),
                    kind=kind,
                    model=model,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    user_id=_if_exists(User.id, user_id),
                    college_id=_if_exists(College.id, college_id),
                    job_id=_if_exists(GenerationJob.id, job_id),
                )
            )
            await session.commit()
    except Exception:  # noqa: BLE001 — la comptabilité ne fait jamais échouer l'appel
        logger.warning(
            "Usage Claude non enregistré (%s, %s, %d/%d tokens, job %s)",
            kind,
            model,
            input_tokens,
            output_tokens,
            job_id,
            exc_info=True,
        )
