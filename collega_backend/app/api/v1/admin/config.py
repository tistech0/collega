"""Routes admin — configuration anti-spam et pilotage (table app_settings).

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
from app.services import admin_pilot, app_settings

router = APIRouter()


async def _config(db: AsyncSession) -> ConfigData:
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    inactivity_days, testflight_url = await admin_pilot.pilot_settings(db)
    return ConfigData(
        reload_count_max=reload_count_max,
        monthly_reloads_max=monthly_reloads_max,
        inactivity_days=inactivity_days,
        testflight_url=testflight_url,
    )


# ── Story 1.4 — Configuration anti-spam ──────────────────────────────────────


@router.get("/config", response_model=ConfigResponseWrapped)
async def get_config(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> ConfigResponseWrapped:
    """Retourne la configuration anti-spam et de pilotage actuelle (table app_settings, défauts .env)."""
    return ConfigResponseWrapped(data=await _config(db))


@router.patch("/config", response_model=ConfigResponseWrapped)
async def update_config(
    body: ConfigUpdateRequest,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> ConfigResponseWrapped:
    """Met à jour la configuration anti-spam et de pilotage en base : vue par tous les
    processus API en 30 s au plus (cache par processus, le worker ne lit pas ces
    réglages), conservée au redémarrage."""
    if body.reload_count_max is not None:
        await app_settings.set_setting(db, app_settings.RELOAD_COUNT_MAX, body.reload_count_max)
    if body.monthly_reloads_max is not None:
        await app_settings.set_setting(db, app_settings.MONTHLY_RELOADS_MAX, body.monthly_reloads_max)
    if body.inactivity_days is not None:
        await app_settings.set_setting(db, admin_pilot.INACTIVITY_DAYS, body.inactivity_days)
    if body.testflight_url is not None:
        await app_settings.set_setting(db, admin_pilot.TESTFLIGHT_URL, body.testflight_url)
    await db.commit()
    return ConfigResponseWrapped(data=await _config(db))
