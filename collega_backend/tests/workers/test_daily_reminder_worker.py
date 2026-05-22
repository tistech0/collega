"""Tests du worker daily_reminder — AC3, AC4 (Story 4.5)."""
from __future__ import annotations

import types
import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.workers.daily_reminder_worker import send_daily_reminders


def _make_user(apns_token="device-token-abc", reminder_hour_utc=None):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        email="test@example.com",
        apns_token=apns_token,
        reminder_hour_utc=reminder_hour_utc,
    )


def _make_mock_db(users: list):
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = users
    mock_db = AsyncMock()
    mock_db.__aenter__ = AsyncMock(return_value=mock_db)
    mock_db.__aexit__ = AsyncMock(return_value=False)
    mock_db.execute = AsyncMock(return_value=mock_result)
    return mock_db


class TestSendDailyReminders:
    async def test_envoie_notification_pour_user_avec_token(self):
        """Un user avec apns_token et reminder_hour_utc == heure courante → send_daily_reminder appelé."""
        current_hour = datetime.now(timezone.utc).hour
        user = _make_user(apns_token="token-xyz", reminder_hour_utc=current_hour)
        mock_db = _make_mock_db([user])
        mock_svc = AsyncMock()
        mock_svc.send_daily_reminder = AsyncMock()

        with patch("app.workers.daily_reminder_worker.async_session_factory", return_value=mock_db):
            with patch(
                "app.workers.daily_reminder_worker.get_notification_service",
                return_value=mock_svc,
            ):
                await send_daily_reminders({})

        mock_svc.send_daily_reminder.assert_called_once_with(user.apns_token)

    async def test_pas_notification_sans_users(self):
        """Aucun user correspondant → send_daily_reminder jamais appelé."""
        mock_db = _make_mock_db([])
        mock_svc = AsyncMock()
        mock_svc.send_daily_reminder = AsyncMock()

        with patch("app.workers.daily_reminder_worker.async_session_factory", return_value=mock_db):
            with patch(
                "app.workers.daily_reminder_worker.get_notification_service",
                return_value=mock_svc,
            ):
                await send_daily_reminders({})

        mock_svc.send_daily_reminder.assert_not_called()

    async def test_erreur_push_loggee_sans_crash(self):
        """Si send_daily_reminder lève une exception, le worker continue sans crash."""
        current_hour = datetime.now(timezone.utc).hour
        user = _make_user(apns_token="token-xyz", reminder_hour_utc=current_hour)
        mock_db = _make_mock_db([user])
        mock_svc = AsyncMock()
        mock_svc.send_daily_reminder = AsyncMock(side_effect=Exception("APNs error"))

        with patch("app.workers.daily_reminder_worker.async_session_factory", return_value=mock_db):
            with patch(
                "app.workers.daily_reminder_worker.get_notification_service",
                return_value=mock_svc,
            ):
                await send_daily_reminders({})

    async def test_plusieurs_users_tous_notifies(self):
        """Plusieurs users → send_daily_reminder appelé pour chacun."""
        current_hour = datetime.now(timezone.utc).hour
        users = [
            _make_user(apns_token="token-1", reminder_hour_utc=current_hour),
            _make_user(apns_token="token-2", reminder_hour_utc=current_hour),
        ]
        mock_db = _make_mock_db(users)
        mock_svc = AsyncMock()
        mock_svc.send_daily_reminder = AsyncMock()

        with patch("app.workers.daily_reminder_worker.async_session_factory", return_value=mock_db):
            with patch(
                "app.workers.daily_reminder_worker.get_notification_service",
                return_value=mock_svc,
            ):
                await send_daily_reminders({})

        assert mock_svc.send_daily_reminder.call_count == 2

    async def test_ctx_notification_service_pris_en_compte(self):
        """Story 7.4 AC #6 : si ctx contient notification_service, get_notification_service(ctx=ctx) le retourne."""
        from app.services.notifications import apns_service

        current_hour = datetime.now(timezone.utc).hour
        user = _make_user(apns_token="token-ctx", reminder_hour_utc=current_hour)
        mock_db = _make_mock_db([user])
        ctx_svc = AsyncMock()
        ctx_svc.send_daily_reminder = AsyncMock()

        # Force le cache module-level à None pour valider que ctx prime.
        apns_service._service_instance = None
        ctx = {"notification_service": ctx_svc}

        with patch(
            "app.workers.daily_reminder_worker.async_session_factory",
            return_value=mock_db,
        ):
            await send_daily_reminders(ctx)

        ctx_svc.send_daily_reminder.assert_awaited_once_with(user.apns_token)
