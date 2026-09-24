"""Routes collèges utilisateur — liste (FR7) et limites de réimport."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.time_utils import next_month_reset as _next_month_reset
from app.deps import get_current_user
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.user import User
from app.schemas.college import (
    CollegesListResponseWrapped,
    ReloadLimitsData,
    ReloadLimitsResponseWrapped,
    UserCollegeData,
)
from app.services import app_settings

router = APIRouter()


@router.get("/colleges", response_model=CollegesListResponseWrapped)
async def list_user_colleges(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollegesListResponseWrapped:
    """Retourne tous les collèges importés par l'utilisateur authentifié."""
    result = await db.execute(select(College).where(College.user_id == current_user.id))
    colleges = result.scalars().all()

    if not colleges:
        return CollegesListResponseWrapped(data=[], total=0)

    college_ids = [c.id for c in colleges]
    count_result = await db.execute(
        select(FlashCard.college_id, FlashCard.rang, func.count(FlashCard.id))
        .where(FlashCard.college_id.in_(college_ids))
        .group_by(FlashCard.college_id, FlashCard.rang)
    )
    counts_by_college: dict[uuid.UUID, dict[str, int]] = {}
    for college_id, rang, count in count_result.all():
        counts_by_college.setdefault(college_id, {})[rang] = count

    data = [
        UserCollegeData(
            college_ref_id=college.college_ref_id,
            college_id=str(college.id),
            status=college.status,
            card_count_a=counts_by_college.get(college.id, {}).get("A", 0),
            card_count_b=counts_by_college.get(college.id, {}).get("B", 0),
            card_count_c=counts_by_college.get(college.id, {}).get("C", 0),
        )
        for college in colleges
    ]

    return CollegesListResponseWrapped(data=data, total=len(data))


@router.get("/colleges/{ref_id}/reload-limits", response_model=ReloadLimitsResponseWrapped)
async def get_college_reload_limits(
    ref_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ReloadLimitsResponseWrapped:
    """Retourne les quotas de reimport pour ce collège (lecture seule)."""
    result = await db.execute(
        select(College).where(College.user_id == current_user.id).where(College.college_ref_id == ref_id)
    )
    college = result.scalar_one_or_none()
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "Collège non trouvé"},
        )

    now = datetime.now(UTC)
    is_month_reset = current_user.monthly_reloads_reset_at is None or now >= current_user.monthly_reloads_reset_at
    effective_monthly = 0 if is_month_reset else current_user.monthly_reloads
    monthly_reset_at = _next_month_reset(now) if is_month_reset else current_user.monthly_reloads_reset_at
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)

    return ReloadLimitsResponseWrapped(
        data=ReloadLimitsData(
            college_reload_count=college.reload_count,
            college_reload_max=reload_count_max,
            monthly_reloads=effective_monthly,
            monthly_max=monthly_reloads_max,
            monthly_reset_at=monthly_reset_at.isoformat(),
        )
    )
