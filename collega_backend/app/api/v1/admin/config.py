"""Routes admin — configuration anti-spam (table app_settings).

Toutes les routes sont protégées par HTTP Basic Auth.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_admin_user
from app.schemas.admin import (
    ConfigData,
    ConfigResponseWrapped,
    ConfigUpdateRequest,
)
from app.services import app_settings

router = APIRouter()


# ── Story 1.4 — Configuration anti-spam ──────────────────────────────────────


@router.get("/config", response_model=ConfigResponseWrapped)
async def get_config(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> ConfigResponseWrapped:
    """Retourne la configuration anti-spam actuelle (table app_settings, défauts .env)."""
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    return ConfigResponseWrapped(
        data=ConfigData(reload_count_max=reload_count_max, monthly_reloads_max=monthly_reloads_max)
    )


@router.patch("/config", response_model=ConfigResponseWrapped)
async def update_config(
    body: ConfigUpdateRequest,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> ConfigResponseWrapped:
    """Met à jour la configuration anti-spam en base : vue par l'API et le worker
    en 30 s au plus (cache par processus), conservée au redémarrage."""
    if body.reload_count_max is not None:
        await app_settings.set_setting(db, app_settings.RELOAD_COUNT_MAX, body.reload_count_max)
    if body.monthly_reloads_max is not None:
        await app_settings.set_setting(db, app_settings.MONTHLY_RELOADS_MAX, body.monthly_reloads_max)
    await db.commit()
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    return ConfigResponseWrapped(
        data=ConfigData(reload_count_max=reload_count_max, monthly_reloads_max=monthly_reloads_max)
    )
