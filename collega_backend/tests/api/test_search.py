"""Tests GET /v1/search — FR36-37 (Story 5.1)."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from app.deps import get_current_user, require_subscription


def _make_user(user_id=None, is_subscribed=True):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="test@example.com",
        is_subscribed=is_subscribed,
        is_beta=False,
    )


def _make_result(item_id=None, rang="A"):
    return {
        "item_id": str(item_id or uuid.uuid4()),
        "item_number": 232,
        "rang": rang,
        "chapter_title": "Insuffisance Cardiaque",
        "college_id": str(uuid.uuid4()),
        "college_ref_id": 1,
        "excerpt": "Élévation du <mark>BNP</mark> en cas d'insuffisance.",
        "rank": 0.8,
    }


class TestSearchEndpoint:
    async def test_search_ok_avec_resultats(self, client: AsyncClient, mock_db):
        """GET /v1/search?q=BNP avec user abonné ayant des fiches → 200, data non vide."""
        from app.main import app

        user = _make_user()
        results = [_make_result(rang="A"), _make_result(rang="B")]
        app.dependency_overrides[get_current_user] = lambda: user
        app.dependency_overrides[require_subscription] = lambda: user

        with patch(
            "app.api.v1.search.search_flash_cards",
            new=AsyncMock(return_value=results),
        ):
            resp = await client.get(
                "/v1/search",
                params={"q": "BNP"},
                headers={"Authorization": "Bearer token"},
            )

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 2
        assert "item_id" in data[0]
        assert "rang" in data[0]
        assert "excerpt" in data[0]
        app.dependency_overrides.clear()

    async def test_search_sans_resultats(self, client: AsyncClient, mock_db):
        """GET /v1/search?q=MotInexistant → 200, data = []."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user
        app.dependency_overrides[require_subscription] = lambda: user

        with patch(
            "app.api.v1.search.search_flash_cards",
            new=AsyncMock(return_value=[]),
        ):
            resp = await client.get(
                "/v1/search",
                params={"q": "MotInexistant"},
                headers={"Authorization": "Bearer token"},
            )

        assert resp.status_code == 200
        assert resp.json()["data"] == []
        app.dependency_overrides.clear()

    async def test_search_query_trop_courte(self, client: AsyncClient, mock_db):
        """GET /v1/search?q=x (1 char) → 422 (min_length=2)."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user
        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.get(
            "/v1/search",
            params={"q": "x"},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 422
        app.dependency_overrides.clear()

    async def test_search_sans_authentification(self, client: AsyncClient, mock_db):
        """GET /v1/search sans token → 401."""
        resp = await client.get("/v1/search", params={"q": "BNP"})
        assert resp.status_code == 401

    async def test_search_user_non_abonne(self, client: AsyncClient, mock_db):
        """GET /v1/search?q=BNP avec user non abonné → 403."""
        from app.main import app

        user = _make_user(is_subscribed=False)
        app.dependency_overrides[get_current_user] = lambda: user

        resp = await client.get(
            "/v1/search",
            params={"q": "BNP"},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 403
        app.dependency_overrides.clear()

    async def test_search_scoped_par_user(self, client: AsyncClient, mock_db):
        """Résultats scoped — user A ne voit pas les fiches de user B."""
        from app.main import app

        user_a = _make_user()
        user_b_id = uuid.uuid4()
        result_user_a = _make_result()

        app.dependency_overrides[get_current_user] = lambda: user_a
        app.dependency_overrides[require_subscription] = lambda: user_a

        captured_user_id = None

        async def mock_search(db, user_id, query):
            nonlocal captured_user_id
            captured_user_id = user_id
            return [result_user_a]

        with patch("app.api.v1.search.search_flash_cards", new=mock_search):
            resp = await client.get(
                "/v1/search",
                params={"q": "BNP"},
                headers={"Authorization": "Bearer token"},
            )

        assert resp.status_code == 200
        assert captured_user_id == user_a.id
        assert captured_user_id != user_b_id
        app.dependency_overrides.clear()
