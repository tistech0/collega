"""GET /v1/colleges/{id}/stream — progression d'un import (stories 7.x, 8.13, chantier 1).

Heartbeat : Cloudflare coupe une connexion silencieuse après ~100 s ; un
commentaire `: keep-alive` part si rien n'a été émis depuis l'intervalle.
Chantier 1 : le flux suit le statut du dernier import (le collège reste prêt
pendant un réimport) et ne retient aucune connexion à la base.
"""

from __future__ import annotations

import json
import types
import uuid

import pytest
from httpx import AsyncClient

from app.api.v1 import colleges as colleges_module
from app.deps import get_current_user_short_session
from app.models.college import College
from tests.api_pg import login_as
from tests.factories import make_college, make_item, make_job, make_user


def _events(body: str) -> list[dict]:
    return [json.loads(f[len("data: ") :]) for f in body.split("\n\n") if f.startswith("data:")]


def _college(user_id, status="processing", progress=3):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user_id,
        college_ref_id=4,
        status=status,
        ocr_page_progress=progress,
        total_pages=10,
        generation_items_done=0,
        generation_items_total=None,
        generation_cards=0,
        generation_preview=None,
    )


def _job(status, **kw):
    return types.SimpleNamespace(status=status, summary_json=kw.get("summary_json"), error_message=kw.get("error"))


@pytest.fixture
def stream_with_states(client: AsyncClient, mock_db, monkeypatch):
    """Rejoue une suite d'états (collège, job) sondage après sondage."""
    user = types.SimpleNamespace(id=uuid.uuid4())

    def _run(college, states):
        from app.main import app

        app.dependency_overrides[get_current_user_short_session] = lambda: user
        college.user_id = user.id

        class _Session:
            async def __aenter__(self):
                return self

            async def __aexit__(self, *a):
                return False

            async def get(self, model, college_id):
                return college

        monkeypatch.setattr(colleges_module, "async_session_factory", lambda: _Session())
        polls = iter(states)

        async def poll(college_id):
            return next(polls)

        monkeypatch.setattr(colleges_module, "_poll_state", poll)
        monkeypatch.setattr(colleges_module, "_SSE_POLL_INTERVAL", 0)
        return client.get(f"/v1/colleges/{college.id}/stream")

    yield _run
    from app.main import app

    app.dependency_overrides.pop(get_current_user_short_session, None)


async def test_keep_alive_when_nothing_changes(stream_with_states, monkeypatch):
    monkeypatch.setattr(colleges_module, "_SSE_HEARTBEAT_INTERVAL", 0)
    c = _college(None)
    job = _job("processing")
    done = _job("generation_complete")
    response = await stream_with_states(c, [(c, job), (c, job), (c, done)])
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    frames = [f for f in response.text.split("\n\n") if f]
    assert frames[0].startswith("data:") and "ocr_progress" in frames[0]
    assert ": keep-alive" in frames
    assert "generation_complete" in frames[-1]


async def test_generation_progress_emitted_only_on_change(stream_with_states, monkeypatch):
    monkeypatch.setattr(colleges_module, "_SSE_HEARTBEAT_INTERVAL", 1000)
    steps = [(0, 3, 0, None), (1, 3, 5, '["Q1 ?"]'), (1, 3, 5, '["Q1 ?"]'), (3, 3, 14, '["Q3 ?", "Q2 ?"]')]
    states = []
    for done, total, cards, preview in steps:
        c = _college(None, status="ocr_complete", progress=10)
        c.generation_items_done, c.generation_items_total, c.generation_cards, c.generation_preview = (
            done,
            total,
            cards,
            preview,
        )
        states.append((c, _job("ocr_complete")))
    states.append((states[-1][0], _job("generation_complete")))
    response = await stream_with_states(states[0][0], states)
    progress = [e["data"] for e in _events(response.text) if e["event"] == "generation_progress"]
    assert progress == [
        {"items_done": 0, "items_total": 3, "cards": 0, "preview": []},
        {"items_done": 1, "items_total": 3, "cards": 5, "preview": ["Q1 ?"]},
        {"items_done": 3, "items_total": 3, "cards": 14, "preview": ["Q3 ?", "Q2 ?"]},
    ]
    assert _events(response.text)[-1]["event"] == "generation_complete"


async def test_reimport_progress_follows_job_while_college_stays_ready(stream_with_states, monkeypatch):
    monkeypatch.setattr(colleges_module, "_SSE_HEARTBEAT_INTERVAL", 1000)
    c = _college(None, status="generation_complete", progress=10)
    c.generation_items_total = 2
    summary = {
        "changed": 1,
        "added": 0,
        "removed": 0,
        "unchanged": 1,
        "cards": 9,
        "claude_calls": 1,
        "quota_refunded": False,
        "reimport": True,
    }
    states = [(c, _job("ocr_complete")), (c, _job("generation_complete", summary_json=json.dumps(summary)))]
    events = _events((await stream_with_states(c, states)).text)
    kinds = [e["event"] for e in events]
    assert "card_generation_started" in kinds and "generation_progress" in kinds
    assert events[-1] == {"event": "generation_complete", "data": {"college_id": str(c.id), "summary": summary}}


async def test_failed_reimport_reports_message_and_intact_content(stream_with_states):
    c = _college(None, status="generation_complete")
    events = _events((await stream_with_states(c, [(c, _job("failed", error="Claude indisponible"))])).text)
    assert events[-1] == {
        "event": "generation_failed",
        "data": {"college_id": str(c.id), "message": "Claude indisponible", "reimport": True},
    }


async def test_failed_first_import_is_not_a_reimport(stream_with_states):
    c = _college(None, status="failed")
    events = _events((await stream_with_states(c, [(c, _job("failed", error="boom"))])).text)
    assert events[-1]["data"]["reimport"] is False


@pytest.mark.pg
async def test_stream_holds_no_request_session(pg_client, pg_factory, monkeypatch):
    """La route SSE n'utilise pas la dépendance get_db (connexion gardée tout le flux)."""
    from app.core.database import get_db
    from app.main import app

    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete")
        job = await make_job(db, college, status="generation_complete")
        job.summary_json = json.dumps({"changed": 0, "reimport": True})
        await db.commit()
    login_as(user)

    async def forbidden():
        raise AssertionError("get_db ne doit pas être utilisé par le flux SSE")
        yield  # pragma: no cover

    app.dependency_overrides[get_db] = forbidden
    response = await pg_client.get(f"/v1/colleges/{college.id}/stream")
    assert response.status_code == 200
    assert _events(response.text)[-1]["data"]["summary"] == {"changed": 0, "reimport": True}


@pytest.mark.pg
async def test_stream_404_for_other_users_college(pg_client, pg_factory):
    async with pg_factory() as db:
        owner = await make_user(db)
        intruder = await make_user(db)
        college = await make_college(db, owner)
        await db.commit()
    login_as(intruder)
    response = await pg_client.get(f"/v1/colleges/{college.id}/stream")
    assert response.status_code == 404


@pytest.mark.pg
async def test_status_and_content_during_reimport(pg_client, pg_factory):
    """Pendant un réimport : /status suit le job, /items et /cards servent l'ancien contenu."""
    from tests.factories import make_card

    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete")
        item = await make_item(db, college, 304, text="contenu")
        await make_card(db, item)
        await make_job(db, college, status="processing")
        await db.commit()
    login_as(user)
    status = (await pg_client.get(f"/v1/colleges/{college.id}/status")).json()["data"]
    assert (status["status"], status["summary"], status["reimport"]) == ("processing", None, False)
    assert (await pg_client.get(f"/v1/colleges/{college.id}/items")).status_code == 200
    cards = (await pg_client.get(f"/v1/colleges/{college.id}/cards")).json()
    assert cards["total"] == 1
    listing = (await pg_client.get("/v1/colleges")).json()["data"]
    assert listing[0]["status"] == "generation_complete"


@pytest.mark.pg
async def test_status_exposes_summary_and_failed_reimport(pg_client, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete")
        done = await make_job(db, college, status="generation_complete")
        done.summary_json = json.dumps({"changed": 2, "reimport": True})
        await db.commit()
    login_as(user)
    status = (await pg_client.get(f"/v1/colleges/{college.id}/status")).json()["data"]
    assert (status["status"], status["summary"]) == ("generation_complete", {"changed": 2, "reimport": True})

    async with pg_factory() as db:
        failed = await make_job(db, await db.get(College, college.id), status="failed")
        await db.commit()
    status = (await pg_client.get(f"/v1/colleges/{college.id}/status")).json()["data"]
    assert (status["status"], status["reimport"], status["job_id"]) == ("failed", True, str(failed.id))


@pytest.mark.pg
async def test_first_import_summary_is_not_exposed(pg_client, pg_factory):
    """Le résumé ne concerne que les réimports : l'app n'affiche pas « 120 nouveaux »."""
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete")
        job = await make_job(db, college, status="generation_complete")
        job.summary_json = json.dumps({"added": 120, "reimport": False})
        await db.commit()
    login_as(user)
    status = (await pg_client.get(f"/v1/colleges/{college.id}/status")).json()["data"]
    assert status["summary"] is None
