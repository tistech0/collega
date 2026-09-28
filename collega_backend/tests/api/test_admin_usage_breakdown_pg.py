"""GET /v1/admin/usage : coût par jour (30 j), par collège (30 j), coût moyen d'un import."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.models.claude_usage import ClaudeUsage
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_college, make_job, make_user

pytestmark = pytest.mark.pg


async def test_ventilation(pg_client: AsyncClient, pg_factory):
    now = datetime.now(UTC)
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, ref_id=4)
        done = await make_job(db, college, status="generation_complete")
        failed = await make_job(db, college, status="failed")

        def usage(job, days_ago, tokens, kind="generation"):
            return ClaudeUsage(
                created_at=now - timedelta(days=days_ago),
                user_id=user.id,
                college_id=college.id,
                job_id=job.id,
                kind=kind,
                model="claude-sonnet-4-6",
                input_tokens=tokens,
                output_tokens=0,
            )

        db.add_all(
            [
                usage(done, 0, 1_000_000),
                usage(done, 2, 1_000_000),
                usage(failed, 1, 5_000_000),
                usage(done, 45, 1_000_000),
            ]
        )
        await db.commit()

    data = (await pg_client.get("/v1/admin/usage", auth=ADMIN_AUTH)).json()["data"]
    assert len(data["daily"]) == 30
    assert data["daily"][-1]["day"] == now.date().isoformat()
    assert data["daily"][-1]["cost_eur"] > 0 and data["daily"][-4]["cost_eur"] == 0
    assert [c["college_name"] for c in data["by_college"]] == ["Cardiologie"]
    # Seul le job terminé compte : 3 M tokens d'entrée sur un job, jours confondus.
    per_million = data["daily"][-1]["cost_eur"]
    assert data["avg_import_cost_eur"] == pytest.approx(3 * per_million, rel=1e-3)


async def test_base_vide(pg_client: AsyncClient):
    data = (await pg_client.get("/v1/admin/usage", auth=ADMIN_AUTH)).json()["data"]
    assert len(data["daily"]) == 30 and all(d["cost_eur"] == 0 for d in data["daily"])
    assert data["by_college"] == [] and data["avg_import_cost_eur"] == 0
