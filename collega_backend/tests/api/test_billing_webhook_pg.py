"""Webhook RevenueCat sur Postgres réel (chantier 2 § 5, revue finale m7) :
verrou de ligne, horodatage stocké, égalité idempotente, événement périmé, borne."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import event, select

from app.models.user import User

AUTH = {"Authorization": "test-rc-secret"}
STORED_AT = datetime(2026, 9, 20, 12, 0, tzinfo=UTC)


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def _payload(event_type: str, user_id, timestamp_ms: int | None) -> dict:
    ev: dict = {"type": event_type, "app_user_id": str(user_id)}
    if timestamp_ms is not None:
        ev["event_timestamp_ms"] = timestamp_ms
    return {"event": ev, "api_version": "1.0"}


async def _make_user(pg_factory, *, is_subscribed: bool, event_at: datetime | None) -> User:
    async with pg_factory() as db:
        user = User(
            id=uuid.uuid4(),
            email=f"{uuid.uuid4().hex[:10]}@test.fr",
            hashed_password="x",
            is_subscribed=is_subscribed,
            subscription_event_at=event_at,
        )
        db.add(user)
        await db.commit()
        return user


async def _reload(pg_factory, user_id) -> User:
    async with pg_factory() as db:
        return (await db.execute(select(User).where(User.id == user_id))).scalar_one()


async def _post(client, payload: dict):
    return await client.post("/v1/webhooks/revenuecat", json=payload, headers=AUTH)


class TestWebhookPostgres:
    async def test_verrou_for_update_et_horodatage_stocke(self, pg_client, pg_factory, pg_engine):
        user = await _make_user(pg_factory, is_subscribed=False, event_at=None)
        statements: list[str] = []

        def _capture(conn, cursor, statement, parameters, context, executemany):
            statements.append(statement)

        event.listen(pg_engine.sync_engine, "before_cursor_execute", _capture)
        try:
            at = datetime(2026, 9, 21, 8, 30, 15, 123000, tzinfo=UTC)
            resp = await _post(pg_client, _payload("INITIAL_PURCHASE", user.id, _ms(at)))
        finally:
            event.remove(pg_engine.sync_engine, "before_cursor_execute", _capture)

        assert resp.status_code == 200
        assert resp.json()["data"] == {"status": "updated", "is_subscribed": True}
        assert any("FROM users" in s and "FOR UPDATE" in s for s in statements)
        stored = await _reload(pg_factory, user.id)
        assert stored.is_subscribed is True
        assert stored.subscription_event_at == at

    async def test_horodatage_egal_applique_idempotent(self, pg_client, pg_factory):
        user = await _make_user(pg_factory, is_subscribed=True, event_at=STORED_AT)

        for _ in range(2):
            resp = await _post(pg_client, _payload("RENEWAL", user.id, _ms(STORED_AT)))
            assert resp.status_code == 200
            assert resp.json()["data"] == {"status": "updated", "is_subscribed": True}

        stored = await _reload(pg_factory, user.id)
        assert stored.is_subscribed is True
        assert stored.subscription_event_at == STORED_AT

    async def test_evenement_perime_rollback_et_rien_ne_change(self, pg_client, pg_factory, monkeypatch):
        from sqlalchemy.ext.asyncio import AsyncSession

        user = await _make_user(pg_factory, is_subscribed=True, event_at=STORED_AT)
        rollbacks: list[AsyncSession] = []
        original = AsyncSession.rollback

        async def _spy(self):
            rollbacks.append(self)
            await original(self)

        monkeypatch.setattr(AsyncSession, "rollback", _spy)
        older = _ms(datetime(2026, 9, 19, 12, 0, tzinfo=UTC))
        resp = await _post(pg_client, _payload("EXPIRATION", user.id, older))
        monkeypatch.undo()

        assert resp.status_code == 200
        assert resp.json() == {"data": {"status": "stale"}}
        assert len(rollbacks) == 1
        stored = await _reload(pg_factory, user.id)
        assert stored.is_subscribed is True
        assert stored.subscription_event_at == STORED_AT

    async def test_horodatage_hors_borne_422(self, pg_client, pg_factory):
        user = await _make_user(pg_factory, is_subscribed=False, event_at=None)

        resp = await _post(pg_client, _payload("INITIAL_PURCHASE", user.id, 253_402_300_800_000))

        assert resp.status_code == 422
        assert resp.json()["detail"]["code"] == "VALIDATION_ERROR"
        stored = await _reload(pg_factory, user.id)
        assert stored.is_subscribed is False
        assert stored.subscription_event_at is None
