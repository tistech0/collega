"""Console de pilotage : GET /v1/admin/pilot, /badges, /colleges, réglages."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import text, update

from app.models.activity_day import ActivityDay
from app.models.claude_usage import ClaudeUsage
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.services.admin_pilot import tester_status
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_card, make_college, make_item, make_job, make_user

pytestmark = pytest.mark.pg

# Le nom importé commence par "test" : sans ce garde, pytest le collecte comme un
# test à part entière (python_functions par défaut = préfixe "test", pas "test_*")
# et échoue au setup faute de fixtures nommées comme ses paramètres.
tester_status.__test__ = False

NOW = datetime(2026, 9, 26, 12, 0, tzinfo=UTC)


def test_tester_status():
    assert tester_status(None, NOW, 5) == "never_seen"
    assert tester_status(NOW - timedelta(days=4, hours=23), NOW, 5) == "active"
    assert tester_status(NOW - timedelta(days=5, minutes=1), NOW, 5) == "inactive"


async def test_401_sans_identifiants(pg_client: AsyncClient):
    for path in ("/v1/admin/pilot", "/v1/admin/badges", "/v1/admin/colleges"):
        assert (await pg_client.get(path)).status_code == 401


async def test_pilot_base_vide(pg_client: AsyncClient):
    resp = await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["testers_total"] == 0
    assert data["active_7d"] == {"value": 0, "previous": 0}
    assert data["testers"] == [] and data["watch_jobs"] == [] and data["running_jobs"] == []
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"] == {
        "testers": 0,
        "imports": 0,
        "quality": 0,
    }


async def test_pilot_chiffres_et_testeuses(pg_client: AsyncClient, pg_factory):
    today = datetime.now(UTC).date()
    now = datetime.now(UTC)
    async with pg_factory() as db:
        active = await make_user(db)
        active.is_beta, active.first_name, active.last_seen_at = True, "Camille", now
        never = await make_user(db)
        never.is_beta = True
        db.add_all(
            [
                ActivityDay(user_id=active.id, day=today, cards_reviewed=30, session_completed=True, streak=6),
                ActivityDay(
                    user_id=active.id,
                    day=today - timedelta(days=3),
                    cards_reviewed=10,
                    session_completed=True,
                    streak=3,
                ),
                ActivityDay(
                    user_id=active.id,
                    day=today - timedelta(days=9),
                    cards_reviewed=7,
                    session_completed=False,
                    streak=0,
                ),
            ]
        )
        await db.commit()

    data = (await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)).json()["data"]
    assert data["testers_total"] == 2
    assert data["active_7d"] == {"value": 1, "previous": 1}
    assert data["cards_7d"] == {"value": 40, "previous": 7}
    rows = {r["email"]: r for r in data["testers"]}
    assert rows[active.email]["status"] == "active"
    assert rows[active.email]["streak"] == 6
    assert rows[active.email]["cards_7d"] == 40
    assert rows[never.email]["status"] == "never_seen"
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["testers"] == 1


async def test_imports_en_echec_et_bloques(pg_client: AsyncClient, pg_factory):
    now = datetime.now(UTC)
    async with pg_factory() as db:
        user = await make_user(db)
        failed = await make_job(db, await make_college(db, user, ref_id=4), status="failed")
        failed.error_message = "OCR illisible"
        old_failed = await make_job(db, await make_college(db, user, ref_id=5), status="failed")
        # `updated_at` est aussi forcé à now() par un trigger Postgres BEFORE UPDATE
        # (migration 003, `update_generation_jobs_updated_at`) : un simple UPDATE ORM
        # ou SQL se le fait écraser. Le désactiver le temps de fixer la valeur passée.
        await db.execute(text("ALTER TABLE generation_jobs DISABLE TRIGGER update_generation_jobs_updated_at"))
        await db.execute(
            update(GenerationJob).where(GenerationJob.id == old_failed.id).values(updated_at=now - timedelta(days=8))
        )
        await db.execute(text("ALTER TABLE generation_jobs ENABLE TRIGGER update_generation_jobs_updated_at"))
        stalled = await make_job(db, await make_college(db, user, ref_id=6), status="processing")
        db.add(
            GenerationJobEvent(
                generation_job_id=stalled.id, event_type="ocr_progress", created_at=now - timedelta(minutes=20)
            )
        )
        running = await make_job(db, await make_college(db, user, ref_id=7), status="processing")
        db.add(
            GenerationJobEvent(
                generation_job_id=running.id, event_type="ocr_progress", created_at=now - timedelta(minutes=1)
            )
        )
        await db.commit()

    data = (await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)).json()["data"]
    kinds = {(w["college_name"], w["kind"]) for w in data["watch_jobs"]}
    assert kinds == {("Cardiologie", "failed"), (_name(6), "stalled")}
    assert [r["job_id"] for r in data["running_jobs"]] == [str(running.id)]
    assert data["failed_imports_7d"]["value"] == 1
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["imports"] == 2


def _name(ref_id: int) -> str:
    from app.core.college_catalog import college_name

    return college_name(ref_id)


async def test_pastille_qualite_et_visite(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, ref_id=4)
        item = await make_item(db, college, 1)
        await make_card(db, item, user_feedback="negative")
        await make_card(db, item, user_feedback="positive")
        await db.commit()

    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["quality"] == 1
    colleges = (await pg_client.get("/v1/admin/colleges", auth=ADMIN_AUTH)).json()["data"]
    assert colleges[0]["college_name"] == "Cardiologie" and colleges[0]["negative_count"] == 1
    assert (await pg_client.post("/v1/admin/badges/quality-seen", auth=ADMIN_AUTH)).status_code == 204
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["quality"] == 0


async def test_cout_30_jours(pg_client: AsyncClient, pg_factory):
    now = datetime.now(UTC)
    async with pg_factory() as db:
        db.add_all(
            [
                ClaudeUsage(
                    created_at=now - timedelta(days=1),
                    kind="generation",
                    model="claude-sonnet-4-6",
                    input_tokens=1_000_000,
                    output_tokens=0,
                ),
                ClaudeUsage(
                    created_at=now - timedelta(days=40),
                    kind="generation",
                    model="claude-sonnet-4-6",
                    input_tokens=1_000_000,
                    output_tokens=0,
                ),
            ]
        )
        await db.commit()
    cost = (await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)).json()["data"]["cost_30d_eur"]
    assert cost["value"] > 0 and cost["value"] == cost["previous"]


async def test_reglages_pilotage(pg_client: AsyncClient):
    data = (await pg_client.get("/v1/admin/config", auth=ADMIN_AUTH)).json()["data"]
    assert data["inactivity_days"] == 5 and data["testflight_url"] == ""
    resp = await pg_client.patch(
        "/v1/admin/config",
        json={"inactivity_days": 3, "testflight_url": "https://testflight.apple.com/join/abc"},
        auth=ADMIN_AUTH,
    )
    assert resp.json()["data"]["inactivity_days"] == 3
    assert (
        await pg_client.patch("/v1/admin/config", json={"testflight_url": "javascript:alert(1)"}, auth=ADMIN_AUTH)
    ).status_code == 422
    assert (await pg_client.patch("/v1/admin/config", json={"inactivity_days": 0}, auth=ADMIN_AUTH)).status_code == 422
