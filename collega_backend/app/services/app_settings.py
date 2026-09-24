"""Réglages applicatifs en base (chantier 5, R4 — spec § 6).

Lecture via un cache mémoire de 30 s par processus, invalidé localement à
l'écriture : l'API, le worker et les autres processus voient une nouvelle valeur
en 30 s au plus. Sans ligne en base, la valeur par défaut (celle du `.env`) s'applique.
"""

from __future__ import annotations

import time
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.app_setting import AppSetting

RELOAD_COUNT_MAX = "reload_count_max"
MONTHLY_RELOADS_MAX = "monthly_reloads_max"
CACHE_TTL_S = 30.0

_MISSING = object()  # aucune ligne en base (mis en cache comme une valeur)
_cache: dict[str, tuple[float, Any]] = {}  # clé → (expiration monotonic, valeur)


async def get_setting(db: AsyncSession, key: str, default: Any) -> Any:
    """Valeur du réglage `key`, ou `default` si aucune ligne n'existe."""
    now = time.monotonic()
    cached = _cache.get(key)
    if cached is not None and now < cached[0]:
        value = cached[1]
    else:
        row = await db.get(AppSetting, key)
        value = row.value if row is not None else _MISSING
        _cache[key] = (now + CACHE_TTL_S, value)
    return default if value is _MISSING else value


async def set_setting(db: AsyncSession, key: str, value: Any) -> None:
    """Crée ou met à jour le réglage (flush, sans commit) et invalide le cache local."""
    row = await db.get(AppSetting, key)
    if row is None:
        db.add(AppSetting(key=key, value=value))
    else:
        row.value = value
    await db.flush()
    _cache.pop(key, None)


async def anti_spam_limits(db: AsyncSession) -> tuple[int, int]:
    """(reload_count_max, monthly_reloads_max) — défauts : valeurs du `.env`."""
    reload_count_max = await get_setting(db, RELOAD_COUNT_MAX, settings.reload_count_max)
    monthly_reloads_max = await get_setting(db, MONTHLY_RELOADS_MAX, settings.monthly_reloads_max)
    return int(reload_count_max), int(monthly_reloads_max)


def clear_cache() -> None:
    """Vide le cache local (tests)."""
    _cache.clear()
