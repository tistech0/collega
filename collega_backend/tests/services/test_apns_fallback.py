"""Jeton sandbox (build Xcode) ou production (TestFlight) : un seul backend sert les deux."""

from __future__ import annotations

import sys
import types

import pytest

from app.core.config import Settings
from app.services.notifications.apns_service import APNsNotificationService


class _FakeApns:
    def __init__(self, description: str | None = None):
        self.description = description
        self.sent = []

    async def send_notification(self, request):
        self.sent.append(request)
        return types.SimpleNamespace(is_successful=self.description is None, description=self.description)


@pytest.fixture(autouse=True)
def _fake_aioapns(monkeypatch):
    mod = types.ModuleType("aioapns")
    mod.NotificationRequest = lambda **kw: types.SimpleNamespace(**kw)
    mod.PushType = types.SimpleNamespace(ALERT="alert")
    monkeypatch.setitem(sys.modules, "aioapns", mod)


async def test_succes_sur_l_environnement_configure_sans_repli():
    primary, fallback = _FakeApns(), _FakeApns()
    await APNsNotificationService(clients=(primary, fallback)).send_daily_reminder("a" * 64)
    assert len(primary.sent) == 1
    assert fallback.sent == []


async def test_bad_device_token_retente_sur_l_autre_environnement():
    primary, fallback = _FakeApns("BadDeviceToken"), _FakeApns()
    await APNsNotificationService(clients=(primary, fallback)).send_daily_reminder("a" * 64)
    assert len(primary.sent) == 1
    assert len(fallback.sent) == 1


async def test_autre_echec_pas_de_repli():
    primary, fallback = _FakeApns("Unregistered"), _FakeApns()
    await APNsNotificationService(clients=(primary, fallback)).send_daily_reminder("a" * 64)
    assert fallback.sent == []


def test_defauts_bundle_de_l_app_et_production():
    fields = Settings.model_fields
    assert fields["apns_bundle_id"].default == "com.matthislesur.collega"
    assert fields["apns_use_sandbox"].default is False
