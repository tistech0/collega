"""GET /v1/admin/usage, coût dans /v1/admin/overview et /v1/admin/jobs/{id} — lus dans
claude_usage (chantier 4, spec § 6), Postgres réel."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.models.claude_usage import ClaudeUsage
from app.services.generation.token_cost import compute_cost_eur
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_college, make_job, make_user

pytestmark = pytest.mark.pg

_OLD = datetime.now(UTC) - timedelta(days=45)


def _usage(kind, model, i, o, *, user=None, college=None, job=None, created_at=None) -> ClaudeUsage:
    return ClaudeUsage(
        id=uuid.uuid4(),
        kind=kind,
        model=model,
        input_tokens=i,
        output_tokens=o,
        user_id=user.id if user else None,
        college_id=college.id if college else None,
        job_id=job.id if job else None,
        created_at=created_at or datetime.now(UTC),
    )


async def _seed(pg_factory):
    async with pg_factory() as db:
        alice = await make_user(db)
        bob = await make_user(db)
        college = await make_college(db, alice)
        job = await make_job(db, college, status="failed")
        db.add_all(
            [
                # Historique repris (Sonnet 4.6, il y a 45 jours) puis job récent en Sonnet 5.
                _usage(
                    "generation", "claude-sonnet-4-6", 1_000_000, 100_000, user=alice, college=college, created_at=_OLD
                ),
                _usage("generation", "claude-sonnet-5", 500_000, 50_000, user=alice, college=college, job=job),
                _usage("generation", "claude-sonnet-5", 300_000, 30_000, user=alice, college=college, job=job),
                _usage("regeneration", "claude-sonnet-5", 2_000, 300, user=bob),
                _usage("evaluation", "claude-haiku-4-5-20251001", 80, 15, user=bob),
                # Compte supprimé : la ligne reste dans les totaux.
                _usage("evaluation", "claude-haiku-4-5-20251001", 100, 20),
            ]
        )
        await db.commit()
    return alice, bob, college, job


def _cost(*rows) -> float:
    """Coût attendu : somme par ligne puis arrondi (même méthode que la route)."""
    from app.core.config import settings
    from app.services.generation.token_cost import cost_usd

    return round(sum(cost_usd(m, i, o) for m, i, o in rows) * settings.usd_eur_rate, 4)


async def test_401_without_credentials(pg_client: AsyncClient):
    assert (await pg_client.get("/v1/admin/usage")).status_code == 401


async def test_empty_usage_is_zero(pg_client: AsyncClient):
    data = (await pg_client.get("/v1/admin/usage", auth=ADMIN_AUTH)).json()["data"]
    assert (data["input_tokens"], data["output_tokens"], data["cost_eur"]) == (0, 0, 0.0)
    assert data["by_user"] == [] and data["by_model"] == {}
    assert set(data["by_kind"]) == {"generation", "regeneration", "evaluation"}
    assert data["last_30_days"] == {"input_tokens": 0, "output_tokens": 0, "cost_eur": 0.0}


async def test_totals_by_user_kind_model_and_last_30_days(pg_client: AsyncClient, pg_factory):
    alice, bob, _, _ = await _seed(pg_factory)

    resp = await pg_client.get("/v1/admin/usage", auth=ADMIN_AUTH)

    assert resp.status_code == 200
    data = resp.json()["data"]
    s46 = ("claude-sonnet-4-6", 1_000_000, 100_000)
    s5a, s5b = ("claude-sonnet-5", 500_000, 50_000), ("claude-sonnet-5", 300_000, 30_000)
    regen = ("claude-sonnet-5", 2_000, 300)
    ev_bob, ev_gone = ("claude-haiku-4-5-20251001", 80, 15), ("claude-haiku-4-5-20251001", 100, 20)
    everything = (s46, s5a, s5b, regen, ev_bob, ev_gone)

    assert data["input_tokens"] == sum(r[1] for r in everything)
    assert data["output_tokens"] == sum(r[2] for r in everything)
    assert data["cost_eur"] == _cost(*everything)
    assert data["last_30_days"] == {
        "input_tokens": sum(r[1] for r in everything[1:]),
        "output_tokens": sum(r[2] for r in everything[1:]),
        "cost_eur": _cost(*everything[1:]),
    }

    assert data["by_kind"]["generation"] == {
        "input_tokens": 1_800_000,
        "output_tokens": 180_000,
        "cost_eur": _cost(s46, s5a, s5b),
    }
    assert data["by_kind"]["regeneration"]["cost_eur"] == _cost(regen)
    assert data["by_kind"]["evaluation"]["input_tokens"] == 180
    assert data["by_model"]["claude-sonnet-4-6"]["cost_eur"] == compute_cost_eur(*s46)
    assert data["by_model"]["claude-sonnet-5"]["input_tokens"] == 802_000
    assert data["by_model"]["claude-haiku-4-5-20251001"]["output_tokens"] == 35

    by_user = {u["email"]: u for u in data["by_user"]}
    assert set(by_user) == {alice.email, bob.email, None}
    a = by_user[alice.email]
    assert a["user_id"] == str(alice.id)
    assert (a["input_tokens"], a["cost_eur"]) == (1_800_000, _cost(s46, s5a, s5b))
    assert a["last_30_days"] == {"input_tokens": 800_000, "output_tokens": 80_000, "cost_eur": _cost(s5a, s5b)}
    b = by_user[bob.email]
    assert b["cost_eur"] == _cost(regen, ev_bob) and b["last_30_days"]["cost_eur"] == _cost(regen, ev_bob)
    assert by_user[None]["user_id"] is None and by_user[None]["input_tokens"] == 100


async def test_overview_shows_cost_of_last_30_days(pg_client: AsyncClient, pg_factory):
    await _seed(pg_factory)
    data = (await pg_client.get("/v1/admin/overview", auth=ADMIN_AUTH)).json()["data"]
    assert data["cost_last_30_days_eur"] == _cost(
        ("claude-sonnet-5", 500_000, 50_000),
        ("claude-sonnet-5", 300_000, 30_000),
        ("claude-sonnet-5", 2_000, 300),
        ("claude-haiku-4-5-20251001", 80, 15),
        ("claude-haiku-4-5-20251001", 100, 20),
    )


async def test_job_detail_cost_read_from_claude_usage(pg_client: AsyncClient, pg_factory):
    _, _, _, job = await _seed(pg_factory)
    data = (await pg_client.get(f"/v1/admin/jobs/{job.id}", auth=ADMIN_AUTH)).json()["data"]
    assert (data["input_tokens"], data["output_tokens"], data["claude_calls"]) == (800_000, 80_000, 2)
    assert data["cost_eur"] == _cost(("claude-sonnet-5", 500_000, 50_000), ("claude-sonnet-5", 300_000, 30_000))


async def test_job_detail_without_usage_is_zero(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        college = await make_college(db, await make_user(db))
        job = await make_job(db, college)
        await db.commit()
    data = (await pg_client.get(f"/v1/admin/jobs/{job.id}", auth=ADMIN_AUTH)).json()["data"]
    assert (data["input_tokens"], data["output_tokens"], data["cost_eur"], data["claude_calls"]) == (0, 0, 0.0, 0)
