"""GET /v1/admin/users/{id} — fiche testeuse de la console de pilotage."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.models.activity_day import ActivityDay
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_card, make_college, make_item, make_job, make_user

pytestmark = pytest.mark.pg


async def test_401_et_404(pg_client: AsyncClient):
    assert (await pg_client.get(f"/v1/admin/users/{uuid.uuid4()}")).status_code == 401
    resp = await pg_client.get(f"/v1/admin/users/{uuid.uuid4()}", auth=ADMIN_AUTH)
    assert resp.status_code == 404
    assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"


async def test_detail_sans_activite(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        await db.commit()
    data = (await pg_client.get(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)).json()["data"]
    assert data["status"] == "never_seen"
    assert data["streak"] == 0 and data["cards_30d"] == 0 and data["sessions_30d"] == 0
    assert len(data["daily"]) == 30
    assert all(d["cards_reviewed"] == 0 for d in data["daily"])
    assert data["colleges"] == [] and data["feedback"] == [] and data["jobs"] == []
    # Reprend les cas de l'ancien test par faux db : identité, quotas, colonnes de base.
    assert data["user_id"] == str(user.id)
    assert data["email"] == user.email
    assert data["is_beta"] is False
    assert data["is_subscribed"] is True
    assert data["monthly_reloads"] == 0
    assert data["monthly_reloads_max"] == 3
    assert data["monthly_reloads_reset_at"] is None
    assert data["created_at"] is not None


async def test_detail_complet(pg_client: AsyncClient, pg_factory):
    today = datetime.now(UTC).date()
    async with pg_factory() as db:
        user = await make_user(db, monthly_reloads=2)
        user.first_name, user.last_seen_at, user.is_beta = "Camille", datetime.now(UTC), True
        college = await make_college(db, user, ref_id=4, status="generation_complete")
        await make_job(db, college, status="generation_complete")
        item = await make_item(db, college, 1)
        await make_card(db, item, recto="Signes de gravité ?", user_feedback="negative")
        db.add_all(
            [
                ActivityDay(user_id=user.id, day=today, cards_reviewed=25, session_completed=True, streak=6),
                ActivityDay(
                    user_id=user.id, day=today - timedelta(days=2), cards_reviewed=10, session_completed=False, streak=4
                ),
                ActivityDay(
                    user_id=user.id, day=today - timedelta(days=45), cards_reviewed=99, session_completed=True, streak=1
                ),
            ]
        )
        await db.commit()

    data = (await pg_client.get(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)).json()["data"]
    assert data["user_id"] == str(user.id)
    assert data["email"] == user.email
    assert data["is_beta"] is True
    assert data["is_subscribed"] is True
    assert data["monthly_reloads"] == 2
    assert data["first_name"] == "Camille" and data["status"] == "active"
    assert data["streak"] == 6 and data["cards_30d"] == 35 and data["sessions_30d"] == 1
    assert data["daily"][-1] == {"day": today.isoformat(), "cards_reviewed": 25, "session_completed": True}
    assert data["daily"][0]["day"] == (today - timedelta(days=29)).isoformat()
    assert data["colleges"][0]["college_ref_id"] == 4
    assert data["colleges"][0]["college_name"] == "Cardiologie"
    assert data["colleges"][0]["card_count"] == 1
    assert data["colleges"][0]["reload_count_max"] == 2
    assert data["feedback"][0]["feedback"] == "negative"
    assert data["feedback"][0]["recto"] == "Signes de gravité ?"
    assert data["feedback"][0]["college_name"] == "Cardiologie"
    assert data["feedback"][0]["item_number"] == 1
    assert len(data["jobs"]) == 1
    assert data["jobs"][0]["card_count"] == 0
    assert data["jobs"][0]["status"] == "generation_complete"
    assert data["jobs"][0]["error_message"] is None
