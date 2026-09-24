"""Pool ARQ unique (chantier 5 § 3) : créé dans le lifespan, servi par `get_arq`."""

from __future__ import annotations

import types
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.errors import AppError


@pytest.fixture
def reset_arq_state():
    from app.main import app

    for attr in ("arq", "arq_connect"):
        if hasattr(app.state, attr):
            delattr(app.state, attr)
    yield app
    for attr in ("arq", "arq_connect"):
        if hasattr(app.state, attr):
            delattr(app.state, attr)


def _request(**state):
    return types.SimpleNamespace(app=types.SimpleNamespace(state=types.SimpleNamespace(**state)))


class TestLifespan:
    async def test_cree_le_pool_au_demarrage_et_le_ferme_a_l_arret(self, monkeypatch, reset_arq_state):
        import app.main as main_module
        from app.core.redis import redis_settings

        pool = MagicMock()
        pool.aclose = AsyncMock()
        create = AsyncMock(return_value=pool)
        monkeypatch.setattr(main_module, "create_pool", create)
        app = reset_arq_state

        async with app.router.lifespan_context(app):
            assert app.state.arq is pool
            create.assert_awaited_once_with(redis_settings)
            pool.aclose.assert_not_awaited()
        pool.aclose.assert_awaited_once()
        assert app.state.arq is None

    async def test_redis_injoignable_l_api_demarre_quand_meme(self, monkeypatch, reset_arq_state):
        import app.main as main_module

        monkeypatch.setattr(main_module, "create_pool", AsyncMock(side_effect=ConnectionError("down")))
        app = reset_arq_state

        async with app.router.lifespan_context(app):
            assert app.state.arq is None

    async def test_reconnexion_paresseuse_sans_tentatives_repetees(self, monkeypatch, reset_arq_state):
        """Le connecteur paresseux ne refait qu'une tentative (pas les 5 du démarrage)."""
        import app.main as main_module

        create = AsyncMock(side_effect=[ConnectionError("down"), MagicMock()])
        monkeypatch.setattr(main_module, "create_pool", create)
        app = reset_arq_state

        async with app.router.lifespan_context(app):
            pool = await app.state.arq_connect()
            assert pool is not None
            lazy_settings = create.await_args_list[1].args[0]
            assert lazy_settings.conn_retries == 0


class TestGetArq:
    async def test_renvoie_le_pool_de_l_application(self):
        from app.deps import get_arq

        pool = MagicMock()
        assert await get_arq(_request(arq=pool)) is pool

    async def test_pool_absent_reconnexion_reussie(self):
        from app.deps import get_arq

        pool = MagicMock()
        connect = AsyncMock(return_value=pool)
        request = _request(arq=None, arq_connect=connect)

        assert await get_arq(request) is pool
        assert request.app.state.arq is pool
        connect.assert_awaited_once()

    async def test_pool_absent_reconnexion_ratee_503(self):
        from app.deps import get_arq

        request = _request(arq=None, arq_connect=AsyncMock(return_value=None))

        with pytest.raises(AppError) as exc:
            await get_arq(request)
        assert exc.value.status_code == 503
        assert exc.value.detail["code"] == "QUEUE_UNAVAILABLE"

    async def test_sans_lifespan_503(self):
        from app.deps import get_arq

        with pytest.raises(AppError) as exc:
            await get_arq(_request())
        assert exc.value.status_code == 503

    async def test_optionnel_renvoie_none_si_indisponible(self):
        from app.deps import get_arq_optional

        assert await get_arq_optional(_request(arq=None, arq_connect=AsyncMock(return_value=None))) is None


class TestAbortArqJob:
    async def test_sans_pool_renvoie_false_sans_lever(self):
        from app.services.jobs.arq_control import abort_arq_job

        assert await abort_arq_job(None, "arq-1") is False

    async def test_admin_stop_sans_redis_force_quand_meme_le_statut(self):
        """`stop_job` dépend de `get_arq_optional` : Redis injoignable ne bloque pas l'arrêt."""
        import inspect

        from app.api.v1.admin.jobs import stop_job
        from app.deps import get_arq_optional

        param = inspect.signature(stop_job).parameters["arq"]
        assert param.default.dependency is get_arq_optional
