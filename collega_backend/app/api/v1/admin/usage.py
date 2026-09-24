"""Routes admin — vue d'ensemble (KPI) et consommation tokens / coût.

Toutes les routes sont protégées par HTTP Basic Auth. Le coût est lu dans
`claude_usage` (une ligne par appel facturé) et calculé à la lecture, au tarif de
chaque modèle.
"""

from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_admin_user
from app.models.claude_usage import USAGE_KINDS, ClaudeUsage
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.schemas.admin import (
    OverviewData,
    OverviewResponseWrapped,
    UsageByUserData,
    UsageData,
    UsageResponseWrapped,
    UsageTotalsData,
)
from app.services.generation.token_cost import UsageTotals

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

    recent = UsageTotals()
    recent_result = await db.execute(
        select(ClaudeUsage.model, func.sum(ClaudeUsage.input_tokens), func.sum(ClaudeUsage.output_tokens))
        .where(ClaudeUsage.created_at >= _thirty_days_ago())
        .group_by(ClaudeUsage.model)
    )
    for model, u_input, u_output in recent_result.all():
        recent.add(model, u_input, u_output)

    return OverviewResponseWrapped(
        data=OverviewData(
            users_total=users_count,
            jobs_by_status=jobs_by_status,
            jobs_failed=jobs_by_status["failed"],
            cost_last_30_days_eur=recent.cost_eur,
        )
    )


# ── Story 7.8, chantier 4 — Consommation tokens / coût (claude_usage) ─────────


def _thirty_days_ago() -> datetime:
    return datetime.now(UTC) - timedelta(days=30)


def _totals(t: UsageTotals) -> UsageTotalsData:
    return UsageTotalsData(input_tokens=t.input_tokens, output_tokens=t.output_tokens, cost_eur=t.cost_eur)


@router.get("/usage", response_model=UsageResponseWrapped)
async def get_usage(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> UsageResponseWrapped:
    """Conso tokens Anthropic + coût € : total, 30 derniers jours, ventilation par
    utilisatrice, par type d'appel et par modèle.

    Une seule requête groupée (utilisatrice, type, modèle, récent) ; le coût est
    cumulé en Python au tarif de chaque modèle, puis arrondi une fois par total.
    Les appels d'un compte supprimé (`user_id` NULL) restent dans les totaux.
    """
    recent_col = (ClaudeUsage.created_at >= _thirty_days_ago()).label("recent")
    rows = (
        await db.execute(
            select(
                ClaudeUsage.user_id,
                User.email,
                ClaudeUsage.kind,
                ClaudeUsage.model,
                recent_col,
                func.sum(ClaudeUsage.input_tokens),
                func.sum(ClaudeUsage.output_tokens),
            )
            .outerjoin(User, User.id == ClaudeUsage.user_id)
            .group_by(ClaudeUsage.user_id, User.email, ClaudeUsage.kind, ClaudeUsage.model, recent_col)
        )
    ).all()

    total, last_30 = UsageTotals(), UsageTotals()
    by_kind: dict[str, UsageTotals] = {kind: UsageTotals() for kind in USAGE_KINDS}
    by_model: dict[str, UsageTotals] = defaultdict(UsageTotals)
    by_user: dict[uuid.UUID | None, tuple[str | None, UsageTotals, UsageTotals]] = {}
    for user_id, email, kind, model, recent, u_input, u_output in rows:
        _, user_total, user_recent = by_user.setdefault(user_id, (email, UsageTotals(), UsageTotals()))
        targets = [total, by_kind.setdefault(kind, UsageTotals()), by_model[model], user_total]
        if recent:
            targets += [last_30, user_recent]
        for t in targets:
            t.add(model, u_input, u_output)

    users = sorted(by_user.items(), key=lambda kv: (kv[1][0] is None, kv[1][0] or ""))
    return UsageResponseWrapped(
        data=UsageData(
            **_totals(total).model_dump(),
            last_30_days=_totals(last_30),
            by_kind={kind: _totals(t) for kind, t in by_kind.items()},
            by_model={model: _totals(t) for model, t in sorted(by_model.items())},
            by_user=[
                UsageByUserData(
                    user_id=str(user_id) if user_id else None,
                    email=email,
                    **_totals(user_total).model_dump(),
                    last_30_days=_totals(user_recent),
                )
                for user_id, (email, user_total, user_recent) in users
            ],
        )
    )
