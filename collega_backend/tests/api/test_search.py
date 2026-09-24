"""Tests GET /v1/search — FR36-37 (Story 5.1) + Story 7.2 (rate limit par user_id)."""

from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

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


class TestSearchRateLimitKey:
    """Story 7.2 AC #3 — clé rate-limit par user_id (et non par IP)."""

    def test_user_id_key_utilise_user_id_si_present(self):
        from app.api.v1.search import _user_id_key

        request = MagicMock()
        request.state.user_id = "abc-123"
        assert _user_id_key(request) == "user:abc-123"

    def test_user_id_key_fallback_ip_si_pas_de_user(self):
        from app.api.v1.search import _user_id_key

        request = MagicMock()
        # Pas de user_id → state.user_id absent (getattr renverra None)
        del request.state.user_id
        # Client direct (hors proxy de confiance) : X-Forwarded-For ignoré (chantier 2 § 4).
        request.client.host = "1.2.3.4"
        request.headers = {"X-Forwarded-For": "6.6.6.6"}
        # fallback IP via get_client_ip → préfixe "ip:" (P8) pour debug Redis
        assert _user_id_key(request) == "ip:1.2.3.4"

    def test_user_id_key_deux_users_distincts_meme_ip(self):
        """Deux utilisateurs distincts (même IP NAT fac) → clés différentes → pas de blocage croisé."""
        from app.api.v1.search import _user_id_key

        req_a = MagicMock()
        req_a.state.user_id = "user-a"
        req_b = MagicMock()
        req_b.state.user_id = "user-b"

        assert _user_id_key(req_a) != _user_id_key(req_b)

    def test_search_decorator_wire_user_id_key(self):
        """@limiter.limit du endpoint /search référence bien `_user_id_key`.

        Inspection de l'AST du module pour vérifier que `key_func=_user_id_key`
        est passé au décorateur — détecte une régression silencieuse en cas de
        retrait/renommage du wiring (mieux que `assert callable(...)`).
        """
        import ast
        import inspect

        from app.api.v1 import search as search_module

        source = inspect.getsource(search_module)
        tree = ast.parse(source)
        wirings: list[str] = []
        for node in ast.walk(tree):
            # `search` est `async def` → AsyncFunctionDef (FunctionDef ne match pas)
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) or node.name != "search":
                continue
            for deco in node.decorator_list:
                if isinstance(deco, ast.Call):
                    for kw in deco.keywords:
                        if kw.arg == "key_func" and isinstance(kw.value, ast.Name):
                            wirings.append(kw.value.id)
        assert "_user_id_key" in wirings, (
            "Décorateur @limiter.limit du endpoint search() doit avoir key_func=_user_id_key (Story 7.2 AC #3)"
        )


class TestSearchLogs:
    async def test_search_term_never_logged(self, client: AsyncClient, mock_db, caplog):
        """Chantier 2 § 6 : le terme cherché n'apparaît dans aucun log (id + nombre de résultats seulement)."""
        import logging

        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user
        app.dependency_overrides[require_subscription] = lambda: user
        term = "insuffisance-cardiaque-secrete"

        with (
            caplog.at_level(logging.DEBUG),
            patch("app.api.v1.search.search_flash_cards", new=AsyncMock(return_value=[_make_result()])),
        ):
            resp = await client.get("/v1/search", params={"q": term}, headers={"Authorization": "Bearer token"})

        assert resp.status_code == 200
        # httpx (client de test) journalise l'URL appelée : ce n'est pas un log de l'application.
        app_logs = "\n".join(r.getMessage() for r in caplog.records if not r.name.startswith("httpx"))
        assert term not in app_logs
        search_logs = [r.getMessage() for r in caplog.records if r.name == "app.api.v1.search"]
        assert search_logs and str(user.id) in search_logs[0] and "1" in search_logs[0]
