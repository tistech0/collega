"""Imports passés en échec depuis le dernier passage, une ligne par import (alerte Telegram).

Lancée chaque minute par le script de santé du NAS (ops/nas/collega-health.sh) :
  docker exec collega-api-1 python -m scripts.import_alerts
Le point de reprise vit dans app_settings (`import_alerts_since`). Au tout premier
passage il est posé à « maintenant » : pas de rafale sur l'historique."""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.college_catalog import college_name
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.services import app_settings

KEY = "import_alerts_since"
MAX_MESSAGE = 200


def _short(message: str | None) -> str:
    text = " ".join((message or "erreur inconnue").split())
    return text if len(text) <= MAX_MESSAGE else text[: MAX_MESSAGE - 1] + "…"


async def collect(db: AsyncSession, now: datetime) -> list[str]:
    raw = await app_settings.get_setting(db, KEY, None)
    if raw is None:
        await app_settings.set_setting(db, KEY, now.isoformat())
        await db.commit()
        return []
    since = datetime.fromisoformat(raw)
    rows = (
        await db.execute(
            select(GenerationJob, College.college_ref_id, User.email)
            .join(College, College.id == GenerationJob.college_id)
            .outerjoin(User, User.id == GenerationJob.user_id)
            .where(GenerationJob.status == "failed", GenerationJob.updated_at > since)
            .order_by(GenerationJob.updated_at)
        )
    ).all()
    if not rows:
        return []
    lines = [
        f"{college_name(ref)} — {email or 'compte supprimé'} : {_short(job.error_message)}" for job, ref, email in rows
    ]
    await app_settings.set_setting(db, KEY, max(job.updated_at for job, _, _ in rows).isoformat())
    await db.commit()
    return lines


async def _run() -> list[str]:
    from app.core.database import async_session_factory, engine

    try:
        async with async_session_factory() as db:
            return await collect(db, datetime.now(UTC))
    finally:
        # Lancé une fois par minute par collega-health.sh dans un process Python
        # jetable : sans dispose(), le pool de connexions asyncpg de cet engine
        # fuit à chaque appel plutôt que d'être fermé avec le process.
        await engine.dispose()


def main() -> int:
    for line in asyncio.run(_run()):
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
