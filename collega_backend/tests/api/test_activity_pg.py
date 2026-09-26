"""Activité des testeuses : last_seen_at et PUT /v1/activity/{day} (console de pilotage)."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.activity_day import ActivityDay
from app.models.user import User
from app.services import activity
from tests.api_pg import login_as
from tests.factories import make_user

pytestmark = pytest.mark.pg


def _today() -> date:
    return datetime.now(UTC).date()


async def _user(pg_factory) -> User:
    async with pg_factory() as db:
        user = await make_user(db)
        await db.commit()
        return user


async def test_activity_day_cascade_a_la_suppression_du_compte(pg_session):
    user = await make_user(pg_session)
    pg_session.add(
        ActivityDay(user_id=user.id, day=date(2026, 9, 26), cards_reviewed=3, session_completed=True, streak=2)
    )
    await pg_session.flush()
    assert user.last_seen_at is None

    await pg_session.delete(user)
    await pg_session.flush()
    rows = (await pg_session.execute(select(ActivityDay))).scalars().all()
    assert rows == []


async def test_put_cree_puis_remplace_sans_additionner(pg_client: AsyncClient, pg_factory):
    user = await _user(pg_factory)
    login_as(user)
    day = _today().isoformat()
    body = {"cards_reviewed": 12, "session_completed": False, "streak": 3}
    resp = await pg_client.put(f"/v1/activity/{day}", json=body)
    assert resp.status_code == 200
    assert resp.json() == {"data": {"day": day, **body}}

    body2 = {"cards_reviewed": 20, "session_completed": True, "streak": 4}
    assert (await pg_client.put(f"/v1/activity/{day}", json=body2)).status_code == 200
    assert (await pg_client.put(f"/v1/activity/{day}", json=body2)).status_code == 200

    async with pg_factory() as db:
        rows = (await db.execute(select(ActivityDay).where(ActivityDay.user_id == user.id))).scalars().all()
        assert [(r.cards_reviewed, r.session_completed, r.streak) for r in rows] == [(20, True, 4)]
        assert (await db.get(User, user.id)).last_seen_at is not None


async def test_put_met_a_jour_updated_at_sur_conflit(pg_client: AsyncClient, pg_factory):
    """Le remplacement (upsert on_conflict) doit bien rafraîchir `updated_at`, pas seulement les compteurs."""
    user = await _user(pg_factory)
    login_as(user)
    day = _today().isoformat()
    await pg_client.put(f"/v1/activity/{day}", json={"cards_reviewed": 1, "session_completed": False, "streak": 0})
    async with pg_factory() as db:
        first_updated_at = (
            (await db.execute(select(ActivityDay).where(ActivityDay.user_id == user.id))).scalar_one().updated_at
        )

    await pg_client.put(f"/v1/activity/{day}", json={"cards_reviewed": 2, "session_completed": True, "streak": 1})
    async with pg_factory() as db:
        second_updated_at = (
            (await db.execute(select(ActivityDay).where(ActivityDay.user_id == user.id))).scalar_one().updated_at
        )

    # Deux transactions distinctes très rapprochées (< 1 ms) sur des connexions poolées
    # différentes peuvent voir `now()` (transaction_timestamp) dans un ordre non strictement
    # croissant selon l'ordonnancement du backend Postgres ; seul le changement de valeur
    # compte ici (la mise à jour n'est pas un no-op), pas le sens de l'écart.
    assert second_updated_at != first_updated_at


@pytest.mark.parametrize("offset", [2, -31])
async def test_put_jour_hors_borne_422(pg_client: AsyncClient, pg_factory, offset):
    login_as(await _user(pg_factory))
    day = (_today() + timedelta(days=offset)).isoformat()
    resp = await pg_client.put(
        f"/v1/activity/{day}", json={"cards_reviewed": 1, "session_completed": False, "streak": 0}
    )
    assert resp.status_code == 422
    assert resp.json()["detail"]["code"] == "ACTIVITY_DAY_OUT_OF_RANGE"


@pytest.mark.parametrize(
    "body",
    [
        {"cards_reviewed": -1, "session_completed": False, "streak": 0},
        {"cards_reviewed": 5001, "session_completed": False, "streak": 0},
        {"cards_reviewed": 1, "session_completed": False, "streak": 3651},
    ],
)
async def test_put_compteurs_invalides_422(pg_client: AsyncClient, pg_factory, body):
    login_as(await _user(pg_factory))
    resp = await pg_client.put(f"/v1/activity/{_today().isoformat()}", json=body)
    assert resp.status_code == 422


async def test_put_sans_jeton_401(pg_client: AsyncClient):
    resp = await pg_client.put(
        f"/v1/activity/{_today().isoformat()}", json={"cards_reviewed": 1, "session_completed": False, "streak": 0}
    )
    assert resp.status_code == 401


def test_touch_last_seen_au_plus_toutes_les_10_minutes():
    now = datetime(2026, 9, 26, 12, 0, tzinfo=UTC)
    user = User(last_seen_at=None)
    assert activity.touch_last_seen(user, now) is True
    assert user.last_seen_at == now
    assert activity.touch_last_seen(user, now + timedelta(minutes=9)) is False
    assert user.last_seen_at == now
    assert activity.touch_last_seen(user, now + timedelta(minutes=10)) is True
    assert user.last_seen_at == now + timedelta(minutes=10)


async def test_login_ecrit_last_seen_at(pg_client: AsyncClient, pg_factory):
    from app.core.security import hash_password

    async with pg_factory() as db:
        user = await make_user(db)
        user.hashed_password = hash_password("motdepasse1")
        await db.commit()
    resp = await pg_client.post("/v1/auth/login", json={"email": user.email, "password": "motdepasse1"})
    assert resp.status_code == 200
    async with pg_factory() as db:
        assert (await db.get(User, user.id)).last_seen_at is not None
