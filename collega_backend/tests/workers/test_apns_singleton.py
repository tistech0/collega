"""Tests du singleton APNs côté worker ARQ (Story 7.4 AC #6)."""
from __future__ import annotations

from unittest.mock import AsyncMock

import pytest

from app.workers.settings import _worker_shutdown, _worker_startup


class TestWorkerApnsSingleton:
    async def test_startup_initializes_service_in_ctx(self):
        """on_startup instancie un NotificationService et l'écrit dans ctx."""
        from app.services.notifications.apns_service import NullNotificationService

        ctx: dict = {}
        await _worker_startup(ctx)
        assert "notification_service" in ctx
        # Default config tests : .p8 / key_id / team_id vides → NullNotificationService.
        assert isinstance(ctx["notification_service"], NullNotificationService)

    async def test_startup_falls_back_to_null_on_failure(self, monkeypatch):
        """Si la factory lève, on_startup met un NullNotificationService au lieu de crash."""
        from app.services.notifications import apns_service
        from app.services.notifications.apns_service import NullNotificationService

        def _broken_create():
            raise FileNotFoundError("Fake .p8 missing")

        monkeypatch.setattr(apns_service, "create_notification_service", _broken_create)

        ctx: dict = {}
        await _worker_startup(ctx)
        assert isinstance(ctx["notification_service"], NullNotificationService)

    async def test_shutdown_calls_close(self):
        """on_shutdown appelle close() sur le service stocké dans ctx."""
        mock_svc = AsyncMock()
        mock_svc.close = AsyncMock()
        ctx: dict = {"notification_service": mock_svc}
        await _worker_shutdown(ctx)
        mock_svc.close.assert_awaited_once()

    async def test_shutdown_no_op_if_no_service(self):
        """Si on_startup a échoué, ctx ne contient pas la clé → on_shutdown ne crash pas."""
        ctx: dict = {}
        # Pas d'exception attendue.
        await _worker_shutdown(ctx)

    async def test_shutdown_swallows_close_exceptions(self):
        """Si close() lève, on_shutdown log et continue sans propager."""
        mock_svc = AsyncMock()
        mock_svc.close = AsyncMock(side_effect=Exception("connection already closed"))
        ctx: dict = {"notification_service": mock_svc}
        # Pas d'exception attendue (cleanup non bloquant).
        await _worker_shutdown(ctx)
        mock_svc.close.assert_awaited_once()


class TestGetNotificationServiceWithCtx:
    async def test_ctx_takes_priority_over_module_singleton(self):
        """get_notification_service(ctx=ctx) retourne le service du ctx s'il existe."""
        from app.services.notifications import apns_service
        from app.services.notifications.apns_service import (
            NullNotificationService,
            get_notification_service,
        )

        # Reset cache module-level
        apns_service._service_instance = None

        ctx_svc = NullNotificationService()
        ctx = {"notification_service": ctx_svc}
        result = get_notification_service(ctx=ctx)
        assert result is ctx_svc

    async def test_fallback_to_module_singleton_when_no_ctx(self):
        """Sans request ni ctx, get_notification_service tombe sur le cache module."""
        from app.services.notifications import apns_service
        from app.services.notifications.apns_service import get_notification_service

        apns_service._service_instance = None
        svc1 = get_notification_service()
        svc2 = get_notification_service()
        assert svc1 is svc2  # même instance cachée
