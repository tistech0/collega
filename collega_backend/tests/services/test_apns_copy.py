"""Textes des notifications : le produit s'appelle Collega (refonte v2)."""
from __future__ import annotations

import sys
import types

import pytest

from app.services.notifications.apns_service import APNsNotificationService


class _FakeApns:
    def __init__(self):
        self.sent = []

    async def send_notification(self, request):
        self.sent.append(request)
        return types.SimpleNamespace(is_successful=True, description=None)


@pytest.fixture(autouse=True)
def _fake_aioapns(monkeypatch):
    """aioapns n'est présent que dans l'image de prod : requête factice qui garde le message."""
    mod = types.ModuleType("aioapns")
    mod.NotificationRequest = lambda **kw: types.SimpleNamespace(**kw)
    mod.PushType = types.SimpleNamespace(ALERT="alert")
    monkeypatch.setitem(sys.modules, "aioapns", mod)


def _service():
    svc = object.__new__(APNsNotificationService)
    svc._apns = _FakeApns()
    return svc


async def test_fiches_pretes_parle_de_collega():
    svc = _service()
    await svc.send_generation_complete("a" * 64, 12)
    alert = svc._apns.sent[0].message["aps"]["alert"]
    assert "Collega" in alert["body"]
    assert "AppMédecine" not in str(alert)
    assert svc._apns.sent[0].message["college_ref_id"] == 12


async def test_rappel_quotidien_titre_collega():
    svc = _service()
    await svc.send_daily_reminder("a" * 64)
    alert = svc._apns.sent[0].message["aps"]["alert"]
    assert alert["title"] == "Collega"
    assert "AppMédecine" not in str(alert)
