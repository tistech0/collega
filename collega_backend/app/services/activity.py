"""Activité des testeuses (console de pilotage) : dernière ouverture et résumé quotidien."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta

from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import unprocessable
from app.models.activity_day import ActivityDay
from app.models.user import User

LAST_SEEN_THROTTLE = timedelta(minutes=10)
MAX_DAYS_BACK = 30
MAX_DAYS_AHEAD = 1  # jour local de l'app en avance sur l'UTC du serveur


def touch_last_seen(user: User, now: datetime) -> bool:
    """Met `last_seen_at` à `now` si elle est vide ou date de 10 min ou plus. L'appelant commite."""
    if user.last_seen_at is not None and now - user.last_seen_at < LAST_SEEN_THROTTLE:
        return False
    user.last_seen_at = now
    return True


def check_day_in_range(day: date, today: date) -> None:
    if not (today - timedelta(days=MAX_DAYS_BACK) <= day <= today + timedelta(days=MAX_DAYS_AHEAD)):
        raise unprocessable("ACTIVITY_DAY_OUT_OF_RANGE", "Jour d'activité hors de la période acceptée.")


async def upsert_day(
    db: AsyncSession,
    user_id: uuid.UUID,
    day: date,
    cards_reviewed: int,
    session_completed: bool,
    streak: int,
) -> None:
    """Remplace le résumé du jour (jamais d'addition : l'app envoie toujours le total)."""
    values = {"cards_reviewed": cards_reviewed, "session_completed": session_completed, "streak": streak}
    stmt = insert(ActivityDay).values(user_id=user_id, day=day, **values)
    stmt = stmt.on_conflict_do_update(
        index_elements=[ActivityDay.user_id, ActivityDay.day],
        set_={**values, "updated_at": func.now()},
    )
    await db.execute(stmt)
