"""Tests du lifespan FastAPI pour le singleton APNs (Story 7.4 AC #5, #7).

Note : `httpx.AsyncClient` + `ASGITransport` ne déclenche pas le lifespan
Starlette — on passe donc directement par `app.router.lifespan_context(app)`
qui est l'API officielle pour piloter le lifecycle en test.
"""

from __future__ import annotations

from unittest.mock import AsyncMock

import pytest


@pytest.fixture
def reset_app_state():
    """Garantit que `app.state.notification_service` est remis à zéro entre tests."""
    from app.main import app

    if hasattr(app.state, "notification_service"):
        delattr(app.state, "notification_service")
    yield
    if hasattr(app.state, "notification_service"):
        delattr(app.state, "notification_service")


class TestLifespanApns:
    async def test_default_settings_initializes_null_service(self, reset_app_state):
        """Sans config APNs (.p8 path/key_id/team_id vides) → NullNotificationService."""
        from app.main import app
        from app.services.notifications.apns_service import NullNotificationService

        async with app.router.lifespan_context(app):
            assert hasattr(app.state, "notification_service")
            assert isinstance(app.state.notification_service, NullNotificationService)

    async def test_apns_creation_failure_falls_back_to_null(self, monkeypatch, reset_app_state):
        """Si create_notification_service lève (ex : .p8 manquant), fallback NullNotificationService."""
        from app.main import app
        from app.services.notifications import apns_service
        from app.services.notifications.apns_service import NullNotificationService

        def _broken_create():
            raise FileNotFoundError("Fake .p8 missing")

        monkeypatch.setattr(apns_service, "create_notification_service", _broken_create)

        async with app.router.lifespan_context(app):
            assert isinstance(app.state.notification_service, NullNotificationService)

    async def test_close_called_at_shutdown(self, monkeypatch, reset_app_state):
        """close() est appelé sur le service au shutdown du lifespan."""
        from app.main import app
        from app.services.notifications import apns_service

        mock_service = AsyncMock()
        mock_service.close = AsyncMock()

        monkeypatch.setattr(
            apns_service,
            "create_notification_service",
            lambda: mock_service,
        )

        async with app.router.lifespan_context(app):
            assert app.state.notification_service is mock_service
        # Sortie du context manager → shutdown → close() appelé une fois.
        mock_service.close.assert_awaited_once()
