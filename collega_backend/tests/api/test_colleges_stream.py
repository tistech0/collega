"""Tests GET /v1/colleges/{id}/stream — heartbeat SSE.

Cloudflare (et la plupart des reverse proxies) coupent une connexion HTTP
sans aucun octet pendant ~100 s. Pendant la génération Claude, le stream
peut rester silencieux plusieurs minutes : un commentaire SSE `: keep-alive`
doit être émis périodiquement pour garder la connexion ouverte.
"""
from __future__ import annotations

import types
import uuid
from contextlib import asynccontextmanager
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.api.v1 import colleges as colleges_module
from app.deps import get_current_user


def _make_user(user_id=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="test@example.com",
        is_subscribed=True,
        is_beta=False,
    )


def _make_college(user_id, status="processing", progress=3):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user_id,
        college_ref_id=4,
        status=status,
        ocr_page_progress=progress,
        total_pages=10,
    )


class TestStreamHeartbeat:
    async def test_emet_un_keep_alive_quand_rien_ne_change(
        self, client: AsyncClient, mock_db, monkeypatch
    ):
        """Poll 1 : progression émise. Poll 2 : rien ne change → heartbeat.
        Poll 3 : generation_complete → fin du stream."""
        user = _make_user()
        college = _make_college(user.id)
        mock_db.get = AsyncMock(return_value=college)

        from app.main import app

        app.dependency_overrides[get_current_user] = lambda: user

        polls = {"n": 0}

        class _Session:
            async def get(self, model, college_id):
                polls["n"] += 1
                if polls["n"] >= 3:
                    college.status = "generation_complete"
                return college

        @asynccontextmanager
        async def _factory():
            yield _Session()

        monkeypatch.setattr(colleges_module, "async_session_factory", _factory)
        monkeypatch.setattr(colleges_module, "_SSE_POLL_INTERVAL", 0)
        monkeypatch.setattr(colleges_module, "_SSE_HEARTBEAT_INTERVAL", 0)

        response = await client.get(f"/v1/colleges/{college.id}/stream")
        app.dependency_overrides.pop(get_current_user, None)

        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/event-stream")
        body = response.text
        frames = [f for f in body.split("\n\n") if f]
        assert frames[0].startswith("data:") and "ocr_progress" in frames[0]
        assert ": keep-alive" in frames, frames
        assert "generation_complete" in frames[-1]
