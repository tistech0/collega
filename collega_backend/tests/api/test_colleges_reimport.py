"""Tests quota de reimport — FR14, FR15, FR18, FR45 + Story 7.2 (atomicité).

L'incrément reload_count / monthly_reloads est maintenant fait au router via
UPDATE atomique avec RETURNING. Le mock `db.execute.side_effect` chaîne :

  1. SELECT College (chargement initial)
  2. SELECT GenerationJob (pre-check job actif)
  3. UPDATE College.reload_count … RETURNING (atomique)
  4. UPDATE User.monthly_reloads … RETURNING (atomique)

Pour les tests non-reimport (status != 'generation_complete'), seuls les
deux premiers SELECT sont exécutés.
"""

from __future__ import annotations

import types
import uuid
from datetime import UTC, datetime, timedelta
from io import BytesIO
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient
from sqlalchemy.exc import IntegrityError

from app.deps import get_current_user, require_subscription
from tests.fakes.fake_arq import arq_pool


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


def _result(value):
    """Mock d'un Result SQLAlchemy avec `.scalar_one_or_none()` configuré."""
    return MagicMock(scalar_one_or_none=MagicMock(return_value=value))


_PDF_BYTES = b"%PDF-1.4 fake pdf content for testing"


@pytest.fixture(autouse=True)
def _readable_pdf(monkeypatch):
    """L'écriture du PDF est simulée ici : l'ouverture réelle (422 PDF_DAMAGED) est
    testée dans test_pdf_damaged.py."""
    from unittest.mock import AsyncMock

    from app.api.v1 import colleges as colleges_module

    monkeypatch.setattr(colleges_module, "assert_pdf_readable", AsyncMock(return_value=1))


_FUTURE = datetime.now(UTC) + timedelta(days=15)


class TestReimportQuotaChecks:
    async def test_reimport_bloque_college_limit(self, client: AsyncClient, mock_db):
        """409 COLLEGE_RELOAD_LIMIT — l'UPDATE atomique RETURNING None signifie saturé."""
        from app.main import app

        user = _make_user()
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=2)
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                _result(college),  # SELECT College
                _result(None),  # SELECT GenerationJob (aucun job actif)
                _result(None),  # UPDATE College RETURNING — saturé → 409 COLLEGE_RELOAD_LIMIT
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

    async def test_reimport_bloque_monthly_limit_rollback_college(self, client: AsyncClient, mock_db):
        """409 MONTHLY_RELOAD_LIMIT — College a été UPDATE OK mais User RETURNING None.

        On vérifie aussi que `db.rollback()` est bien appelé pour annuler
        l'incrément College fait juste avant.
        """
        from app.main import app

        user = _make_user(monthly_reloads=3, monthly_reloads_reset_at=_FUTURE)
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=0)
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                _result(college),  # SELECT College
                _result(None),  # SELECT GenerationJob
                _result(1),  # UPDATE College RETURNING 1 (OK)
                _result(None),  # UPDATE User RETURNING None → saturé → 409
            ]
        )
        mock_db.rollback = AsyncMock()

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
        # Rollback explicite pour annuler l'incrément college
        mock_db.rollback.assert_awaited_once()

    async def test_monthly_reset_at_none_effective_zero(self, client: AsyncClient, mock_db):
        """Si monthly_reloads_reset_at is None → reset lazy → user peut faire un reimport."""
        import uuid as _uuid
        from unittest.mock import AsyncMock as _AM
        from unittest.mock import MagicMock as _MM
        from unittest.mock import patch

        from app.main import app

        user = _make_user(monthly_reloads=3, monthly_reloads_reset_at=None)
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=0)
        college.id = _uuid.uuid4()
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                _result(college),  # SELECT College
                _result(None),  # SELECT GenerationJob
                _result(1),  # UPDATE College RETURNING 1 (premier reload, le reset_lazy a remis monthly=0)
                _result(1),  # UPDATE User RETURNING 1 (incrément OK après reset lazy)
            ]
        )

        mock_arq_job = _MM()
        mock_arq_job.job_id = "arq-test"
        mock_pool = _AM()
        mock_pool.enqueue_job = _AM(return_value=mock_arq_job)
        mock_pool.close = _AM()

        with (
            patch("app.api.v1.colleges.Path.mkdir"),
            patch("builtins.open", _MM()),
            arq_pool(mock_pool),
        ):
            resp = await client.post(
                "/v1/colleges/15/import",
                files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code != 409 or resp.json()["detail"]["code"] not in (
            "COLLEGE_RELOAD_LIMIT",
            "MONTHLY_RELOAD_LIMIT",
        )

    async def test_premier_import_non_bloque(self, client: AsyncClient, mock_db):
        """Premier import (status != generation_complete) → aucun UPDATE atomique nécessaire."""
        from unittest.mock import AsyncMock as _AM
        from unittest.mock import MagicMock as _MM
        from unittest.mock import patch

        from app.main import app

        user = _make_user()
        college = _make_college(ref_id=15, user_id=user.id, status="pending", reload_count=99)
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                _result(college),  # SELECT College
                _result(None),  # SELECT GenerationJob
            ]
        )

        mock_arq_job = _MM()
        mock_arq_job.job_id = "arq-test"
        mock_pool = _AM()
        mock_pool.enqueue_job = _AM(return_value=mock_arq_job)
        mock_pool.close = _AM()

        with (
            patch("app.api.v1.colleges.Path.mkdir"),
            patch("builtins.open", _MM()),
            arq_pool(mock_pool),
        ):
            resp = await client.post(
                "/v1/colleges/15/import",
                files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code not in (409,) or resp.json()["detail"]["code"] not in (
            "COLLEGE_RELOAD_LIMIT",
            "MONTHLY_RELOAD_LIMIT",
        )

    async def test_import_dans_les_limites_retourne_202(self, client: AsyncClient, mock_db):
        """Reimport OK — UPDATE atomique réussit pour College et User."""
        import uuid as _uuid
        from unittest.mock import AsyncMock as _AM
        from unittest.mock import MagicMock as _MM
        from unittest.mock import patch

        from app.main import app

        user = _make_user(monthly_reloads=2, monthly_reloads_reset_at=_FUTURE)
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete", reload_count=1)
        college.id = _uuid.uuid4()
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                _result(college),  # SELECT College
                _result(None),  # SELECT GenerationJob
                _result(2),  # UPDATE College RETURNING 2
                _result(3),  # UPDATE User RETURNING 3
            ]
        )

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
            arq_pool(mock_pool),
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


class TestUniqueProcessingIntegrity:
    """Story 7.2 AC #4 — la contrainte UNIQUE partial index sur generation_jobs
    se manifeste via IntegrityError au commit du nouveau job. Le router doit
    renvoyer 409 JOB_IN_PROGRESS (et non 500)."""

    async def test_integrity_error_commit_returns_409_job_in_progress(self, client: AsyncClient, mock_db):
        import uuid as _uuid
        from unittest.mock import AsyncMock as _AM
        from unittest.mock import MagicMock as _MM
        from unittest.mock import patch

        from app.main import app

        user = _make_user()
        # status != generation_complete → pas de quota check, le code va directement
        # créer le job et faire commit (qui va lever IntegrityError).
        college = _make_college(ref_id=15, user_id=user.id, status="pending", reload_count=0)
        college.id = _uuid.uuid4()
        app.dependency_overrides[require_subscription] = lambda: user

        mock_db.execute = AsyncMock(
            side_effect=[
                _result(college),  # SELECT College
                _result(None),  # SELECT GenerationJob (pre-check vide, le doublon n'est pas encore créé)
            ]
        )
        mock_db.commit = AsyncMock(side_effect=IntegrityError("INSERT", {}, Exception("UNIQUE")))
        mock_db.rollback = AsyncMock()

        mock_pool = _AM()
        mock_pool.enqueue_job = _AM(return_value=_MM(job_id="x"))
        mock_pool.close = _AM()

        with (
            patch("app.api.v1.colleges.Path.mkdir"),
            patch("builtins.open", _MM()),
            arq_pool(mock_pool),
        ):
            resp = await client.post(
                "/v1/colleges/15/import",
                files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")},
            )
        app.dependency_overrides.pop(require_subscription, None)

        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "JOB_IN_PROGRESS"
        mock_db.rollback.assert_awaited()


class TestGetReloadLimits:
    async def test_reload_limits_retourne_compteurs(self, client: AsyncClient, mock_db):
        """GET /v1/colleges/{ref_id}/reload-limits → 200 avec les bons compteurs."""
        from app.main import app

        user = _make_user(monthly_reloads=1, monthly_reloads_reset_at=_FUTURE)
        college = _make_college(ref_id=15, user_id=user.id, reload_count=1)
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.execute = AsyncMock(return_value=_result(college))

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

        mock_db.execute = AsyncMock(return_value=_result(college))

        resp = await client.get("/v1/colleges/15/reload-limits")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        assert resp.json()["data"]["monthly_reloads"] == 0

    async def test_reload_limits_404_si_college_inexistant(self, client: AsyncClient, mock_db):
        """GET /v1/colleges/{ref_id}/reload-limits → 404 si collège inconnu."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        mock_db.execute = AsyncMock(return_value=_result(None))

        resp = await client.get("/v1/colleges/99/reload-limits")
        app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"
