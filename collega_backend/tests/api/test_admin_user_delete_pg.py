"""DELETE /v1/admin/users/{id} — suppression d'un compte depuis la console de pilotage."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.activity_day import ActivityDay
from app.models.college import College
from app.models.user import User
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_college, make_job, make_user

pytestmark = pytest.mark.pg


async def test_401_et_404(pg_client: AsyncClient):
    assert (await pg_client.delete(f"/v1/admin/users/{uuid.uuid4()}")).status_code == 401
    resp = await pg_client.delete(f"/v1/admin/users/{uuid.uuid4()}", auth=ADMIN_AUTH)
    assert resp.status_code == 404
    assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"


async def test_supprime_le_compte_et_ses_donnees(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, ref_id=4, status="generation_complete")
        await make_job(db, college, status="generation_complete")
        db.add(
            ActivityDay(
                user_id=user.id, day=datetime.now(UTC).date(), cards_reviewed=3, session_completed=True, streak=1
            )
        )
        await db.commit()

    resp = await pg_client.delete(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)
    assert resp.status_code == 204

    async with pg_factory() as db:
        assert await db.get(User, user.id) is None
        assert (await db.execute(select(College).where(College.user_id == user.id))).scalars().all() == []
        assert (await db.execute(select(ActivityDay).where(ActivityDay.user_id == user.id))).scalars().all() == []


async def test_refuse_si_un_import_tourne(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        await make_job(db, await make_college(db, user), status="processing")
        await db.commit()

    resp = await pg_client.delete(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)
    assert resp.status_code == 409
    assert resp.json()["detail"]["code"] == "JOB_ACTIVE"
    async with pg_factory() as db:
        assert await db.get(User, user.id) is not None
