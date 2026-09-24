"""Routes admin — vue d'ensemble (KPI) et consommation tokens / coût.

Toutes les routes sont protégées par HTTP Basic Auth.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_admin_user
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.schemas.admin import (
    OverviewData,
    OverviewResponseWrapped,
    UsageByUserData,
    UsageData,
    UsageResponseWrapped,
)
from app.services.generation.token_cost import compute_cost_eur

router = APIRouter()


# ── Story 7.6 — Overview KPI (point d'entrée console) ─────────────────────────

_JOB_STATUSES = ("pending", "processing", "ocr_complete", "generation_complete", "failed")


@router.get("/overview", response_model=OverviewResponseWrapped)
async def get_overview(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> OverviewResponseWrapped:
    """KPI d'accueil console : total users, jobs par statut, jobs failed."""
    users_total = await db.execute(select(func.count()).select_from(User))
    users_count = users_total.scalar_one()

    jobs_result = await db.execute(select(GenerationJob.status, func.count()).group_by(GenerationJob.status))
    counts = {status: count for status, count in jobs_result.all()}
    jobs_by_status = {status: counts.get(status, 0) for status in _JOB_STATUSES}

    return OverviewResponseWrapped(
        data=OverviewData(
            users_total=users_count,
            jobs_by_status=jobs_by_status,
            jobs_failed=jobs_by_status["failed"],
        )
    )


# ── Story 7.8 — Consommation tokens / coût ────────────────────────────────────


@router.get("/usage", response_model=UsageResponseWrapped)
async def get_usage(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> UsageResponseWrapped:
    """Conso tokens Anthropic + coût € : total global + ventilation par user.

    Les jobs `NULL` (non mesurés, antérieurs migration 014) comptent comme 0 via
    `func.coalesce`. Le coût € est calculé à la lecture (jamais persisté).
    """
    global_result = await db.execute(
        select(
            func.coalesce(func.sum(GenerationJob.input_tokens), 0),
            func.coalesce(func.sum(GenerationJob.output_tokens), 0),
        )
    )
    g_input, g_output = global_result.one()

    by_user_result = await db.execute(
        select(
            User.id,
            User.email,
            func.coalesce(func.sum(GenerationJob.input_tokens), 0),
            func.coalesce(func.sum(GenerationJob.output_tokens), 0),
        )
        .join(GenerationJob, GenerationJob.user_id == User.id)
        .group_by(User.id, User.email)
        .order_by(User.email)
    )
    by_user = [
        UsageByUserData(
            user_id=str(uid),
            email=email,
            input_tokens=u_input,
            output_tokens=u_output,
            cost_eur=compute_cost_eur(u_input, u_output),
        )
        for uid, email, u_input, u_output in by_user_result.all()
    ]

    return UsageResponseWrapped(
        data=UsageData(
            input_tokens=g_input,
            output_tokens=g_output,
            cost_eur=compute_cost_eur(g_input, g_output),
            by_user=by_user,
        )
    )
