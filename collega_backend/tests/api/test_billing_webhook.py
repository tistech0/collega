"""Tests POST /v1/webhooks/revenuecat — webhook billing RevenueCat."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

VALID_SECRET = "test-rc-secret"
VALID_AUTH_HEADER = VALID_SECRET


def make_user(user_id=None, is_subscribed=False):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="user@test.com",
        is_beta=False,
        is_subscribed=is_subscribed,
        monthly_reloads=0,
    )


def webhook_payload(event_type: str, app_user_id: str | None = None) -> dict:
    return {
        "event": {
            "type": event_type,
            "app_user_id": app_user_id or str(uuid.uuid4()),
        },
        "api_version": "1.0",
    }


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
