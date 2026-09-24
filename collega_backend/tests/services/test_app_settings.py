"""Réglages applicatifs en base (chantier 5, R4) — service, cache mémoire 30 s."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.services import app_settings
from app.services.app_settings import (
    CACHE_TTL_S,
    MONTHLY_RELOADS_MAX,
    RELOAD_COUNT_MAX,
    anti_spam_limits,
    get_setting,
    set_setting,
)


class _Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


async def test_get_setting_sans_ligne_renvoie_le_defaut(sqlite_session: AsyncSession):
    assert await get_setting(sqlite_session, "inconnu", 42) == 42


async def test_set_puis_get(sqlite_session: AsyncSession):
    await set_setting(sqlite_session, RELOAD_COUNT_MAX, 7)
    assert await get_setting(sqlite_session, RELOAD_COUNT_MAX, 2) == 7


async def test_set_met_a_jour_une_ligne_existante(sqlite_session: AsyncSession):
    await set_setting(sqlite_session, RELOAD_COUNT_MAX, 7)
    await set_setting(sqlite_session, RELOAD_COUNT_MAX, 9)
    assert await get_setting(sqlite_session, RELOAD_COUNT_MAX, 2) == 9


async def test_le_cache_sert_l_ancienne_valeur_jusqu_a_expiration(sqlite_session: AsyncSession, monkeypatch):
    clock = _Clock()
    monkeypatch.setattr(app_settings.time, "monotonic", clock)
    assert await get_setting(sqlite_session, MONTHLY_RELOADS_MAX, 3) == 3  # mis en cache

    # Écriture par un autre processus : le cache local n'est pas invalidé.
    await sqlite_session.execute(app_settings.AppSetting.__table__.insert().values(key=MONTHLY_RELOADS_MAX, value=10))
    clock.now += CACHE_TTL_S - 1
    assert await get_setting(sqlite_session, MONTHLY_RELOADS_MAX, 3) == 3

    clock.now += 2  # cache expiré
    assert await get_setting(sqlite_session, MONTHLY_RELOADS_MAX, 3) == 10


async def test_set_invalide_le_cache_local(sqlite_session: AsyncSession):
    assert await get_setting(sqlite_session, RELOAD_COUNT_MAX, 2) == 2
    await set_setting(sqlite_session, RELOAD_COUNT_MAX, 5)
    assert await get_setting(sqlite_session, RELOAD_COUNT_MAX, 2) == 5


async def test_anti_spam_limits_defauts_env(sqlite_session: AsyncSession):
    assert await anti_spam_limits(sqlite_session) == (settings.reload_count_max, settings.monthly_reloads_max)


async def test_anti_spam_limits_valeurs_en_base(sqlite_session: AsyncSession):
    await set_setting(sqlite_session, RELOAD_COUNT_MAX, 4)
    await set_setting(sqlite_session, MONTHLY_RELOADS_MAX, 0)
    assert await anti_spam_limits(sqlite_session) == (4, 0)
