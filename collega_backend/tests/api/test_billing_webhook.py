"""Tests POST /v1/webhooks/revenuecat — webhook billing RevenueCat."""

from __future__ import annotations

import types
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, patch

from httpx import AsyncClient

VALID_SECRET = "test-rc-secret"
VALID_AUTH_HEADER = VALID_SECRET


def make_user(user_id=None, is_subscribed=False, subscription_event_at=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="user@test.com",
        is_beta=False,
        is_subscribed=is_subscribed,
        monthly_reloads=0,
        subscription_event_at=subscription_event_at,
    )


def webhook_payload(event_type: str, app_user_id: str | None = None, event_timestamp_ms: int | None = None) -> dict:
    event: dict = {"type": event_type, "app_user_id": app_user_id or str(uuid.uuid4())}
    if event_timestamp_ms is not None:
        event["event_timestamp_ms"] = event_timestamp_ms
    return {"event": event, "api_version": "1.0"}


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


STORED_AT = datetime(2026, 9, 20, 12, 0, tzinfo=UTC)


class TestRevenueCatWebhook:
    async def test_401_without_authorization_header(self, client: AsyncClient):
        user_id = str(uuid.uuid4())
        resp = await client.post(
            "/v1/webhooks/revenuecat",
            json=webhook_payload("INITIAL_PURCHASE", user_id),
        )
        assert resp.status_code == 401

    async def test_401_with_wrong_secret(self, client: AsyncClient):
        user_id = str(uuid.uuid4())
        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("INITIAL_PURCHASE", user_id),
                headers={"Authorization": "wrong-secret"},
            )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "INVALID_SIGNATURE"

    async def test_404_for_unknown_user(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        user_id = str(uuid.uuid4())

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("INITIAL_PURCHASE", user_id),
                headers={"Authorization": VALID_AUTH_HEADER},
            )
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"

    async def test_initial_purchase_sets_subscribed_true(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=False)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("INITIAL_PURCHASE", str(user.id)),
                headers={"Authorization": VALID_AUTH_HEADER},
            )

        assert resp.status_code == 200
        assert user.is_subscribed is True
        mock_db.commit.assert_called_once()

    async def test_renewal_sets_subscribed_true(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=False)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("RENEWAL", str(user.id)),
                headers={"Authorization": VALID_AUTH_HEADER},
            )

        assert resp.status_code == 200
        assert user.is_subscribed is True

    async def test_cancellation_sets_subscribed_false(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=True)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("CANCELLATION", str(user.id)),
                headers={"Authorization": VALID_AUTH_HEADER},
            )

        assert resp.status_code == 200
        assert user.is_subscribed is False

    async def test_expiration_sets_subscribed_false(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=True)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("EXPIRATION", str(user.id)),
                headers={"Authorization": VALID_AUTH_HEADER},
            )

        assert resp.status_code == 200
        assert user.is_subscribed is False

    async def test_unknown_event_returns_200_no_change(self, client: AsyncClient, mock_db):
        """Event neutre (TEST_EVENT) → 200 sans modification DB."""
        user = make_user(is_subscribed=True)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("TEST_EVENT", str(user.id)),
                headers={"Authorization": VALID_AUTH_HEADER},
            )

        assert resp.status_code == 200
        assert resp.json()["data"]["status"] == "ignored"
        mock_db.commit.assert_not_called()

    async def test_bearer_prefix_stripped_from_authorization(self, client: AsyncClient, mock_db):
        """Authorization: Bearer <secret> → le préfixe est strippé défensivement."""
        user = make_user(is_subscribed=False)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("RENEWAL", str(user.id)),
                headers={"Authorization": f"Bearer {VALID_SECRET}"},
            )

        assert resp.status_code == 200
        assert user.is_subscribed is True

    async def test_uncancellation_sets_subscribed_true(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=False)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("UNCANCELLATION", str(user.id)),
                headers={"Authorization": VALID_AUTH_HEADER},
            )

        assert resp.status_code == 200
        assert user.is_subscribed is True
        mock_db.commit.assert_called_once()

    async def test_product_change_sets_subscribed_true(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=False)
        mock_db.get = AsyncMock(return_value=user)
        mock_db.commit = AsyncMock()

        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("PRODUCT_CHANGE", str(user.id)),
                headers={"Authorization": VALID_AUTH_HEADER},
            )

        assert resp.status_code == 200
        assert user.is_subscribed is True
        mock_db.commit.assert_called_once()

    async def test_422_for_invalid_uuid(self, client: AsyncClient, mock_db):
        with patch("app.api.v1.billing.settings") as mock_settings:
            mock_settings.revenuecat_webhook_secret = VALID_SECRET
            resp = await client.post(
                "/v1/webhooks/revenuecat",
                json=webhook_payload("INITIAL_PURCHASE", "not-a-uuid"),
                headers={"Authorization": VALID_AUTH_HEADER},
            )
        assert resp.status_code == 422


class TestAuthBeforeBody:
    """Chantier 2 § 5 : le secret est vérifié AVANT toute lecture du corps."""

    async def test_401_without_secret_even_with_invalid_body(self, client: AsyncClient):
        resp = await client.post(
            "/v1/webhooks/revenuecat",
            content=b"{not json",
            headers={"Content-Type": "application/json"},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "INVALID_SIGNATURE"

    async def test_401_wrong_secret_with_schema_invalid_body(self, client: AsyncClient):
        resp = await client.post(
            "/v1/webhooks/revenuecat",
            json={"event": {}},
            headers={"Authorization": "wrong-secret"},
        )
        assert resp.status_code == 401

    async def test_secret_and_malformed_json_422_validation_error(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/webhooks/revenuecat",
            content=b"{not json",
            headers={"Authorization": VALID_AUTH_HEADER, "Content-Type": "application/json"},
        )
        assert resp.status_code == 422
        assert resp.json()["detail"]["code"] == "VALIDATION_ERROR"
        mock_db.get.assert_not_called()

    async def test_secret_and_schema_invalid_body_422_validation_error(self, client: AsyncClient, mock_db):
        resp = await client.post(
            "/v1/webhooks/revenuecat",
            json={"event": {"type": "RENEWAL"}},
            headers={"Authorization": VALID_AUTH_HEADER},
        )
        assert resp.status_code == 422
        detail = resp.json()["detail"]
        assert detail["code"] == "VALIDATION_ERROR"
        assert detail["errors"][0]["loc"] == ["body", "event", "app_user_id"]
        # Jamais la valeur reçue dans la réponse.
        assert all("input" not in e for e in detail["errors"])


class TestEventOrdering:
    """Chantier 2 § 5 : un événement antérieur au dernier appliqué est ignoré (`stale`)."""

    async def _post(self, client: AsyncClient, payload: dict):
        return await client.post("/v1/webhooks/revenuecat", json=payload, headers={"Authorization": VALID_AUTH_HEADER})

    async def test_older_event_is_stale_and_changes_nothing(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=True, subscription_event_at=STORED_AT)
        mock_db.get = AsyncMock(return_value=user)
        older = _ms(datetime(2026, 9, 19, 12, 0, tzinfo=UTC))

        resp = await self._post(client, webhook_payload("EXPIRATION", str(user.id), older))

        assert resp.status_code == 200
        assert resp.json() == {"data": {"status": "stale"}}
        assert user.is_subscribed is True
        assert user.subscription_event_at == STORED_AT
        mock_db.commit.assert_not_called()

    async def test_newer_event_applied_and_timestamp_stored(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=True, subscription_event_at=STORED_AT)
        mock_db.get = AsyncMock(return_value=user)
        newer_dt = datetime(2026, 9, 21, 8, 30, 15, 123000, tzinfo=UTC)

        resp = await self._post(client, webhook_payload("EXPIRATION", str(user.id), _ms(newer_dt)))

        assert resp.status_code == 200
        assert resp.json()["data"] == {"status": "updated", "is_subscribed": False}
        assert user.is_subscribed is False
        assert user.subscription_event_at == newer_dt
        mock_db.commit.assert_called_once()

    async def test_first_timestamped_event_applied(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=False, subscription_event_at=None)
        mock_db.get = AsyncMock(return_value=user)

        resp = await self._post(client, webhook_payload("INITIAL_PURCHASE", str(user.id), _ms(STORED_AT)))

        assert resp.status_code == 200
        assert user.is_subscribed is True
        assert user.subscription_event_at == STORED_AT

    async def test_event_without_timestamp_applied_timestamp_unchanged(self, client: AsyncClient, mock_db):
        user = make_user(is_subscribed=True, subscription_event_at=STORED_AT)
        mock_db.get = AsyncMock(return_value=user)

        resp = await self._post(client, webhook_payload("CANCELLATION", str(user.id)))

        assert resp.status_code == 200
        assert user.is_subscribed is False
        assert user.subscription_event_at == STORED_AT
        mock_db.commit.assert_called_once()

    async def test_user_row_locked_for_update(self, client: AsyncClient, mock_db):
        # Deux webhooks concurrents pour la même utilisatrice se sérialisent sur la ligne.
        user = make_user()
        mock_db.get = AsyncMock(return_value=user)

        await self._post(client, webhook_payload("RENEWAL", str(user.id), _ms(STORED_AT)))

        assert mock_db.get.await_args.kwargs.get("with_for_update") is True
