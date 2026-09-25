"""GET/PATCH /v1/admin/config sur Postgres : réglages anti-spam en base (chantier 5, R4)."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.core.config import settings
from app.services import app_settings
from app.services.app_settings import CACHE_TTL_S, MONTHLY_RELOADS_MAX, RELOAD_COUNT_MAX, get_setting, set_setting
from tests.api_pg import ADMIN_AUTH, login_as
from tests.factories import make_college, make_user

pytestmark = pytest.mark.pg


async def test_401_sans_identifiants(pg_client: AsyncClient):
    assert (await pg_client.get("/v1/admin/config")).status_code == 401
    assert (await pg_client.patch("/v1/admin/config", json={"reload_count_max": 5})).status_code == 401


async def test_get_sans_ligne_renvoie_les_defauts_env(pg_client: AsyncClient):
    resp = await pg_client.get("/v1/admin/config", auth=ADMIN_AUTH)
    assert resp.status_code == 200
    assert resp.json() == {
        "data": {"reload_count_max": settings.reload_count_max, "monthly_reloads_max": settings.monthly_reloads_max}
    }


async def test_patch_puis_get(pg_client: AsyncClient, pg_factory):
    resp = await pg_client.patch("/v1/admin/config", json={"reload_count_max": 7}, auth=ADMIN_AUTH)
    assert resp.status_code == 200
    assert resp.json()["data"] == {"reload_count_max": 7, "monthly_reloads_max": settings.monthly_reloads_max}

    resp = await pg_client.patch("/v1/admin/config", json={"monthly_reloads_max": 0}, auth=ADMIN_AUTH)
    assert resp.json()["data"] == {"reload_count_max": 7, "monthly_reloads_max": 0}

    app_settings.clear_cache()  # relu depuis la base, pas depuis le cache
    resp = await pg_client.get("/v1/admin/config", auth=ADMIN_AUTH)
    assert resp.json()["data"] == {"reload_count_max": 7, "monthly_reloads_max": 0}
    # Le .env n'est pas modifié : il reste la valeur par défaut.
    assert settings.reload_count_max == 2


async def test_patch_valeur_negative_422(pg_client: AsyncClient, pg_factory):
    resp = await pg_client.patch("/v1/admin/config", json={"reload_count_max": -1}, auth=ADMIN_AUTH)
    assert resp.status_code == 422
    async with pg_factory() as db:
        assert await get_setting(db, RELOAD_COUNT_MAX, None) is None


async def test_valeur_vue_par_un_autre_processus(pg_factory, monkeypatch):
    now = [1000.0]
    monkeypatch.setattr(app_settings.time, "monotonic", lambda: now[0])
    async with pg_factory() as db:
        assert await get_setting(db, MONTHLY_RELOADS_MAX, 3) == 3  # en cache

    # « Autre processus » : écrit en base, puis son cache local est oublié.
    async with pg_factory() as db:
        await set_setting(db, MONTHLY_RELOADS_MAX, 12)
        await db.commit()
    app_settings._cache[MONTHLY_RELOADS_MAX] = (now[0] + CACHE_TTL_S, 3)  # cache du processus lecteur

    async with pg_factory() as db:
        assert await get_setting(db, MONTHLY_RELOADS_MAX, 3) == 3  # cache pas encore expiré
        now[0] += CACHE_TTL_S + 1
        assert await get_setting(db, MONTHLY_RELOADS_MAX, 3) == 12  # expiré : relu en base

    app_settings.clear_cache()
    async with pg_factory() as db:
        assert await get_setting(db, MONTHLY_RELOADS_MAX, 3) == 12


async def test_quota_de_reimport_applique_la_valeur_en_base(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete", reload_count=1)
        await db.commit()
    login_as(user)

    # Défaut .env (2) : 1 réimport sur 2, encore autorisé.
    resp = await pg_client.get(f"/v1/colleges/{college.college_ref_id}/reload-limits")
    assert resp.json()["data"]["college_reload_max"] == 2

    resp = await pg_client.patch("/v1/admin/config", json={"reload_count_max": 1}, auth=ADMIN_AUTH)
    assert resp.status_code == 200

    resp = await pg_client.get(f"/v1/colleges/{college.college_ref_id}/reload-limits")
    assert resp.json()["data"]["college_reload_max"] == 1

    resp = await pg_client.post(
        f"/v1/colleges/{college.college_ref_id}/import",
        files={"pdf": ("c.pdf", b"%PDF-1.4 x", "application/pdf")},
    )
    assert resp.status_code == 409
    detail = resp.json()["detail"]
    assert detail["code"] == "COLLEGE_RELOAD_LIMIT"
    assert detail["reload_count_max"] == 1


async def test_me_expose_la_limite_mensuelle_en_base(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        await set_setting(db, MONTHLY_RELOADS_MAX, 8)
        await db.commit()
    app_settings.clear_cache()
    login_as(user)

    resp = await pg_client.get("/v1/auth/me")
    assert resp.json()["data"]["monthly_reloads_max"] == 8
