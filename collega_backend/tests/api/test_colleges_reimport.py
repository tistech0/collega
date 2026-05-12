"""Tests quota de reimport — FR14, FR15, FR18, FR45."""
from __future__ import annotations

import types
import uuid
from datetime import datetime, timedelta, timezone
from io import BytesIO
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from app.deps import get_current_user, require_subscription


def _make_user(user_id=None, monthly_reloads=0, monthly_reloads_reset_at=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="test@example.com",
        is_subscribed=True,
        is_beta=False,
        monthly_reloads=monthly_reloads,
        monthly_reloads_reset_at=monthly_reloads_reset_at,
    )


def _make_college(ref_id: int, college_id=None, user_id=None, status="generation_complete", reload_count=0):
    return types.SimpleNamespace(
        id=college_id or uuid.uuid4(),
        user_id=user_id or uuid.uuid4(),
        college_ref_id=ref_id,
        status=status,
        reload_count=reload_count,
        ocr_page_progress=0,
        total_pages=None,
    )


_PDF_BYTES = b"%PDF-1.4 fake pdf content for testing"
_FUTURE = datetime.now(timezone.utc) + timedelta(days=15)


class TestReimportQuotaChecks:
    async def test_reimport_bloque_college_limit(self, client: AsyncClient, mock_db):
        """409 COLLEGE_RELOAD_LIMIT quand reload_count >= max (default 2)."""
        from app.main import app

        user = _make_user()
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=2)
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),  # college trouvé
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),      # aucun job actif
            ]
        )

        resp = await client.post(
            "/v1/colleges/15/import",
            files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
        )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 409
        detail = resp.json()["detail"]
        assert detail["code"] == "COLLEGE_RELOAD_LIMIT"
        assert detail["reload_count"] == 2
        assert detail["reload_count_max"] == 2

    async def test_reimport_bloque_monthly_limit(self, client: AsyncClient, mock_db):
        """409 MONTHLY_RELOAD_LIMIT quand monthly_reloads >= max et reset_at dans le futur."""
        from app.main import app

        user = _make_user(monthly_reloads=3, monthly_reloads_reset_at=_FUTURE)
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=0)
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
            ]
        )

        resp = await client.post(
            "/v1/colleges/15/import",
            files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
        )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 409
        detail = resp.json()["detail"]
        assert detail["code"] == "MONTHLY_RELOAD_LIMIT"
        assert detail["monthly_reloads"] == 3
        assert detail["monthly_max"] == 3
        assert "reset_at" in detail

    async def test_monthly_reset_at_none_effective_zero(self, client: AsyncClient, mock_db):
        """Si monthly_reloads_reset_at is None → auto-reset → effective_monthly = 0 → pas bloqué."""
        from app.main import app
        import uuid as _uuid

        # monthly_reloads = 3 mais reset_at = None → effective = 0, auto-reset
        user = _make_user(monthly_reloads=3, monthly_reloads_reset_at=None)
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=0)
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
            ]
        )
        # Faire passer le commit sans erreur
        college.id = college.id or _uuid.uuid4()

        from unittest.mock import patch, MagicMock as _MM, AsyncMock as _AM
        mock_arq_job = _MM()
        mock_arq_job.job_id = "arq-test"
        mock_pool = _AM()
        mock_pool.enqueue_job = _AM(return_value=mock_arq_job)
        mock_pool.close = _AM()

        with (
            patch("app.api.v1.colleges.Path.mkdir"),
            patch("builtins.open", _MM()),
            patch("arq.create_pool", _AM(return_value=mock_pool)),
        ):
            resp = await client.post(
                "/v1/colleges/15/import",
                files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )
        app.dependency_overrides.pop(require_subscription, None)

        # Pas de 409 quota → doit passer (202 ou éventuellement 503 si arq mock incomplet)
        assert resp.status_code != 409 or resp.json()["detail"]["code"] not in (
            "COLLEGE_RELOAD_LIMIT",
            "MONTHLY_RELOAD_LIMIT",
        )

    async def test_premier_import_non_bloque(self, client: AsyncClient, mock_db):
        """Premier import (college.status != 'generation_complete') → pas de quota check."""
        from app.main import app

        user = _make_user()
        # college avec reload_count élevé mais status != generation_complete
        college = _make_college(ref_id=15, user_id=user.id, status="pending", reload_count=99)
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
            ]
        )

        from unittest.mock import patch, MagicMock as _MM, AsyncMock as _AM
        mock_arq_job = _MM()
        mock_arq_job.job_id = "arq-test"
        mock_pool = _AM()
        mock_pool.enqueue_job = _AM(return_value=mock_arq_job)
        mock_pool.close = _AM()

        with (
            patch("app.api.v1.colleges.Path.mkdir"),
            patch("builtins.open", _MM()),
            patch("arq.create_pool", _AM(return_value=mock_pool)),
        ):
            resp = await client.post(
                "/v1/colleges/15/import",
                files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )
        app.dependency_overrides.pop(require_subscription, None)

        # Pas bloqué par quota
        assert resp.status_code not in (409,) or resp.json()["detail"]["code"] not in (
            "COLLEGE_RELOAD_LIMIT",
            "MONTHLY_RELOAD_LIMIT",
        )

    async def test_import_dans_les_limites_retourne_202(self, client: AsyncClient, mock_db):
        """Import OK (reload_count=1, monthly=2, dans les limites) → 202."""
        from app.main import app
        import uuid as _uuid

        user = _make_user(monthly_reloads=2, monthly_reloads_reset_at=_FUTURE)
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=1)
        college.id = _uuid.uuid4()
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
            ]
        )

        from unittest.mock import patch, MagicMock as _MM, AsyncMock as _AM
        mock_arq_job = _MM()
        mock_arq_job.job_id = "arq-ok"
        mock_pool = _AM()
        mock_pool.enqueue_job = _AM(return_value=mock_arq_job)
        mock_pool.close = _AM()

        async def mock_refresh(obj):
            pass
        mock_db.refresh = mock_refresh

        with (
            patch("app.api.v1.colleges.Path.mkdir"),
            patch("builtins.open", _MM()),
            patch("arq.create_pool", _AM(return_value=mock_pool)),
        ):
            resp = await client.post(
                "/v1/colleges/15/import",
                files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 202
        data = resp.json()["data"]
        assert "college_id" in data
        assert "job_id" in data


class TestGetReloadLimits:
    async def test_reload_limits_retourne_compteurs(self, client: AsyncClient, mock_db):
        """GET /v1/colleges/{ref_id}/reload-limits → 200 avec les bons compteurs."""
        from app.main import app

        user = _make_user(monthly_reloads=1, monthly_reloads_reset_at=_FUTURE)
        college = _make_college(ref_id=15, user_id=user.id, reload_count=1)
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=college))
        )

        resp = await client.get("/v1/colleges/15/reload-limits")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["college_reload_count"] == 1
        assert data["college_reload_max"] == 2
        assert data["monthly_reloads"] == 1
        assert data["monthly_max"] == 3
        assert "monthly_reset_at" in data

    async def test_reload_limits_retourne_zero_si_auto_reset(self, client: AsyncClient, mock_db):
        """Si monthly_reloads_reset_at est None → monthly_reloads retourné = 0 (auto-reset virtuel)."""
        from app.main import app

        user = _make_user(monthly_reloads=3, monthly_reloads_reset_at=None)
        college = _make_college(ref_id=15, user_id=user.id, reload_count=0)
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=college))
        )

        resp = await client.get("/v1/colleges/15/reload-limits")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        assert resp.json()["data"]["monthly_reloads"] == 0

    async def test_reload_limits_404_si_college_inexistant(self, client: AsyncClient, mock_db):
        """GET /v1/colleges/{ref_id}/reload-limits → 404 si collège inconnu."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )

        resp = await client.get("/v1/colleges/99/reload-limits")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"
