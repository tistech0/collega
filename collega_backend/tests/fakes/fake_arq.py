"""Faux pool ARQ (chantier 5 § 3) : injection par surcharge de dépendance, jamais de vrai Redis."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock


def make_fake_arq(job_id: str = "arq-test") -> MagicMock:
    pool = MagicMock()
    pool.enqueue_job = AsyncMock(return_value=MagicMock(job_id=job_id))
    pool.aclose = AsyncMock()
    return pool


def override_arq(pool) -> None:
    """Branche `pool` comme pool ARQ de l'application (dépendances `get_arq` et `get_arq_optional`)."""
    from app.deps import get_arq, get_arq_optional
    from app.main import app

    app.dependency_overrides[get_arq] = lambda: pool
    app.dependency_overrides[get_arq_optional] = lambda: pool


def arq_pool(pool):
    """Context manager : `pool` sert de pool ARQ le temps du bloc (surcharges restaurées à la sortie)."""
    from unittest.mock import patch

    from app.deps import get_arq, get_arq_optional
    from app.main import app

    return patch.dict(app.dependency_overrides, {get_arq: lambda: pool, get_arq_optional: lambda: pool})
