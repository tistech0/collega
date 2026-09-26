"""Activité des testeuses : last_seen_at et PUT /v1/activity/{day} (console de pilotage)."""

from __future__ import annotations

from datetime import date

import pytest
from sqlalchemy import select

from app.models.activity_day import ActivityDay
from tests.factories import make_user

pytestmark = pytest.mark.pg


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
