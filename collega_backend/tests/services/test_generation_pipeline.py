"""Génération par item, réutilisation et worker de génération (chantier 1), Postgres réel."""
import asyncio
import uuid

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.college import College
from app.models.content import ItemGeneration, JobItem
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.services.generation import pipeline
from app.services.generation.claude_client import CardGenResult, FlashCardData
from app.services.generation.pipeline import generate_job_items
from app.workers import generation_worker, ocr_worker
from app.workers.generation_worker import run_generation
from app.workers.ocr_worker import run_ocr
from tests.factories import cards, make_card, make_college, make_draft, make_item, make_job, make_user, write_pdf
from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401
from tests.workers.test_ocr_pipeline import PAGES, FakeDetector, FakeProcessor

pytestmark = pytest.mark.pg


class FakeClaude:
    def __init__(self, *, fail_on_call: int | None = None, empty_for: set[int] = frozenset()):
        self.calls: list[int] = []
        self.fail_on_call = fail_on_call
        self.empty_for = empty_for

    async def generate_cards(self, item_number, rang, text):
        self.calls.append(item_number)
        if self.fail_on_call is not None and len(self.calls) == self.fail_on_call:
            raise RuntimeError("Claude indisponible")
        if item_number in self.empty_for:
            return CardGenResult(cards=[], input_tokens=50, output_tokens=5)
        return CardGenResult(
            cards=[FlashCardData("classique", f"Q{item_number} ?", f"R{item_number}")],
            input_tokens=100, output_tokens=10,
        )


class Notifications:
    def __init__(self):
        self.sent = []

    async def send_generation_complete(self, token, ref_id, summary=None):
        self.sent.append(("complete", ref_id, summary))

    async def send_import_failed(self, token, ref_id, reimport):
        self.sent.append(("failed", ref_id, reimport))


@pytest.fixture
def notifications(monkeypatch):
    spy = Notifications()
    monkeypatch.setattr(generation_worker, "get_notification_service", lambda ctx=None: spy)
    monkeypatch.setattr("app.services.jobs.job_failure.get_notification_service", lambda: spy)
    return spy


@pytest.fixture(autouse=True)
def storage(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    return tmp_path


async def _ready_job(pg_factory, drafts: dict[int, str], *, college_status="ocr_complete", user=None):
    async with pg_factory() as db:
        user = user or await make_user(db)
        college = await make_college(db, user, status=college_status, ref_id=34)
        job = await make_job(db, college, status="ocr_complete")
        for n, text in drafts.items():
            await make_draft(db, job, n, text, None)
        await db.commit()
    return user, college, job


async def _run(pg_factory, college, job, claude, **kw):
    return await run_generation(pg_factory, college.id, job.id, claude, progress=None, **kw)


async def test_generates_each_draft_and_publishes(pg_factory, notifications):
    _, college, job = await _ready_job(pg_factory, {304: "texte 304", 305: "texte 305"})
    claude = FakeClaude()
    result = await _run(pg_factory, college, job, claude)
    assert claude.calls == [304, 305]
    assert (result["added"], result["cards"], result["claude_calls"]) == (2, 2, 2)
    async with pg_factory() as s:
        j = await s.get(GenerationJob, job.id)
        assert (j.status, j.input_tokens, j.output_tokens, j.hash_shared) == ("generation_complete", 200, 20, False)
    assert notifications.sent == [("complete", 34, None)]  # premier import : message simple


async def test_reuses_generation_of_another_user_without_calling_claude(pg_factory, notifications):
    _, other_college, other_job = await _ready_job(pg_factory, {304: "même texte"})
    await _run(pg_factory, other_college, other_job, FakeClaude())
    # L'autre utilisatrice régénère sa fiche : jamais propagé.
    async with pg_factory() as s:
        card = (await s.execute(select(FlashCard).where(FlashCard.college_id == other_college.id))).scalar_one()
        card.recto, card.generation_id = "modifiée par elle", None
        await s.commit()

    _, college, job = await _ready_job(pg_factory, {304: "même texte"})
    claude = FakeClaude()
    result = await _run(pg_factory, college, job, claude)
    assert claude.calls == [] and result["claude_calls"] == 0
    async with pg_factory() as s:
        mine = (await s.execute(select(FlashCard).where(FlashCard.college_id == college.id))).scalar_one()
        assert mine.recto == "Q304 ?"
        assert (await s.get(GenerationJob, job.id)).hash_shared is True


async def test_new_generation_version_calls_claude_again(pg_factory, notifications, monkeypatch):
    _, c1, j1 = await _ready_job(pg_factory, {304: "texte"})
    await _run(pg_factory, c1, j1, FakeClaude())
    monkeypatch.setattr(pipeline, "GENERATION_VERSION", "claude-sonnet-4-6:p2")
    _, c2, j2 = await _ready_job(pg_factory, {304: "texte"})
    claude = FakeClaude()
    await _run(pg_factory, c2, j2, claude)
    assert claude.calls == [304]
    async with pg_factory() as s:
        assert (await s.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 2


async def test_error_midway_then_relaunch_does_not_repay(pg_factory, notifications, monkeypatch):
    user, college, job = await _ready_job(pg_factory, {301: "a", 302: "b", 303: "c"})
    monkeypatch.setattr(generation_worker, "async_session_factory", pg_factory)
    monkeypatch.setattr(generation_worker, "ClaudeClient", lambda: FakeClaude(fail_on_call=2))
    with pytest.raises(RuntimeError):
        await generation_worker.generate_college_cards({}, str(college.id), str(job.id), "x.pdf")
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "failed"
        assert (await s.get(College, college.id)).status == "failed"
        assert (await s.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 1
    assert notifications.sent == [("failed", 34, False)]

    # L'utilisatrice relance l'import (nouveau job, mêmes textes) : seul 302 et 303 repassent par Claude.
    async with pg_factory() as db:
        college = await db.get(College, college.id)
        job2 = await make_job(db, college, status="ocr_complete")
        for n, t in {301: "a", 302: "b", 303: "c"}.items():
            await make_draft(db, job2, n, t, None)
        await db.commit()
    claude = FakeClaude()
    await _run(pg_factory, college, job2, claude)
    assert claude.calls == [302, 303]


async def test_interruption_then_arq_retry_does_not_repay(pg_factory, notifications, monkeypatch):
    _, college, job = await _ready_job(pg_factory, {301: "a", 302: "b", 303: "c"})

    class Interrupting(FakeClaude):
        async def generate_cards(self, item_number, rang, text):
            if item_number == 302:
                raise asyncio.CancelledError()
            return await super().generate_cards(item_number, rang, text)

    monkeypatch.setattr(generation_worker, "async_session_factory", pg_factory)
    monkeypatch.setattr(generation_worker, "ClaudeClient", lambda: Interrupting())
    with pytest.raises(asyncio.CancelledError):
        await generation_worker.generate_college_cards({}, str(college.id), str(job.id), "x.pdf")
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "ocr_complete"  # reste reprenable
    claude = FakeClaude()
    result = await _run(pg_factory, college, job, claude)  # relance ARQ du même job
    assert claude.calls == [302, 303]
    assert result["added"] == 3


async def test_tokens_accumulated_even_without_cards(pg_factory, notifications):
    _, college, job = await _ready_job(pg_factory, {304: "texte"})
    result = await _run(pg_factory, college, job, FakeClaude(empty_for={304}))
    assert result["cards"] == 0
    async with pg_factory() as s:
        j = await s.get(GenerationJob, job.id)
        assert (j.input_tokens, j.output_tokens) == (50, 5)
        assert (await s.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 0
        assert (await s.execute(select(func.count()).select_from(Item))).scalar_one() == 1


async def test_stop_between_items(pg_factory, notifications):
    _, college, job = await _ready_job(pg_factory, {301: "a", 302: "b"})

    class StopAfterFirst(FakeClaude):
        async def generate_cards(self, item_number, rang, text):
            r = await super().generate_cards(item_number, rang, text)
            async with pg_factory() as s:
                (await s.get(GenerationJob, job.id)).status = "failed"
                await s.commit()
            return r

    claude = StopAfterFirst()
    result = await _run(pg_factory, college, job, claude)
    assert result["error"] == "cancelled" and claude.calls == [301]
    async with pg_factory() as s:
        assert (await s.execute(select(func.count()).select_from(Item))).scalar_one() == 0


async def test_deleted_account_stops_generation(pg_factory, notifications):
    user, college, job = await _ready_job(pg_factory, {301: "a", 302: "b"})

    class DeleteAfterFirst(FakeClaude):
        async def generate_cards(self, item_number, rang, text):
            r = await super().generate_cards(item_number, rang, text)
            async with pg_factory() as s:
                await s.delete(await s.get(User, user.id))
                await s.commit()
            return r

    claude = DeleteAfterFirst()
    result = await _run(pg_factory, college, job, claude)
    assert result["error"] == "cancelled" and claude.calls == [301]


async def test_same_pdf_reimport_end_to_end(pg_factory, notifications, storage):
    """OCR → génération → réimport du même PDF : 0 appel Claude, quota rendu, fiches intactes."""
    async with pg_factory() as db:
        user = await make_user(db, monthly_reloads=0)
        college = await make_college(db, user)
        job1 = await make_job(db, college)
        await db.commit()
    write_pdf(storage, college, job1)
    await run_ocr(pg_factory, college.id, job1.id, "x.pdf", processor=FakeProcessor(PAGES), detector=FakeDetector())
    await _run(pg_factory, college, job1, FakeClaude())
    async with pg_factory() as s:
        first_ids = set((await s.execute(select(FlashCard.id))).scalars())
        # Le router consomme le quota du réimport avant de créer le job.
        c = await s.get(College, college.id)
        c.reload_count = 1
        (await s.get(User, user.id)).monthly_reloads = 1
        job2 = await make_job(s, c)
        await s.commit()
    pdf2 = write_pdf(storage, college, job2)
    await run_ocr(pg_factory, college.id, job2.id, "x.pdf", processor=FakeProcessor(PAGES), detector=FakeDetector())
    claude = FakeClaude()
    result = await _run(pg_factory, college, job2, claude)

    assert claude.calls == []
    assert (result["unchanged"], result["changed"], result["quota_refunded"]) == (2, 0, True)
    async with pg_factory() as s:
        assert set((await s.execute(select(FlashCard.id))).scalars()) == first_ids
        assert (await s.get(College, college.id)).reload_count == 0
        assert (await s.get(User, user.id)).monthly_reloads == 0
    assert notifications.sent[-1][0] == "complete" and notifications.sent[-1][2]["quota_refunded"] is True
    # Ancien PDF supprimé, PDF courant conservé.
    assert [p.name for p in storage.glob("*.pdf")] == [pdf2.name]


async def test_progress_reported_per_item(pg_factory, notifications):
    _, college, job = await _ready_job(pg_factory, {301: "a", 302: "b"})
    seen = []

    async def progress(college_id, **kw):
        seen.append((kw["items_done"], kw["items_total"], kw["cards"], kw["preview"]))

    await run_generation(pg_factory, college.id, job.id, FakeClaude(), progress=progress)
    assert seen == [(0, 2, 0, []), (1, 2, 1, ["Q301 ?"]), (2, 2, 2, ["Q302 ?", "Q301 ?"])]


async def test_not_ocr_complete_is_ignored(pg_factory, notifications):
    _, college, job = await _ready_job(pg_factory, {301: "a"})
    async with pg_factory() as s:
        (await s.get(GenerationJob, job.id)).status = "failed"
        await s.commit()
    claude = FakeClaude()
    assert (await _run(pg_factory, college, job, claude))["error"] == "invalid_job_state"
    assert claude.calls == []
