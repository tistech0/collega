"""Résumé quotidien d'activité envoyé par l'app (console de pilotage de la beta)."""

from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.activity import ActivityDayData, ActivityDayRequest, ActivityDayResponseWrapped
from app.services import activity

router = APIRouter(tags=["activity"])


@router.put("/activity/{day}", response_model=ActivityDayResponseWrapped)
async def put_activity_day(
    day: date,
    body: ActivityDayRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ActivityDayResponseWrapped:
    now = datetime.now(UTC)
    activity.check_day_in_range(day, now.date())
    await activity.upsert_day(db, current_user.id, day, body.cards_reviewed, body.session_completed, body.streak)
    if activity.touch_last_seen(current_user, now):
        # `current_user` peut ne pas être rattaché à cette session (ex. override de test
        # de `get_current_user`) : merge le réattache par clé primaire avant le commit.
        await db.merge(current_user)
    await db.commit()
    return ActivityDayResponseWrapped(data=ActivityDayData(day=day, **body.model_dump()))
