"""Génération par item, réutilisation et worker de génération (chantier 1), Postgres réel."""

import asyncio
import contextlib
import json

import anthropic
import httpx
import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.models.content import ItemGeneration
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.services.generation import pipeline
from app.services.generation.claude_client import CardGenResult, FlashCardData
from app.workers import generation_worker
from app.workers.generation_worker import run_generation
from app.workers.ocr_worker import run_ocr
from tests.factories import make_card, make_college, make_draft, make_item, make_job, make_user, write_pdf
from tests.workers.test_ocr_pipeline import PAGES, FakeDetector, FakeProcessor

pytestmark = pytest.mark.pg


class FakeClaude:
    def __init__(
        self,
        *,
        fail_on_call: int | None = None,
        empty_for: set[int] = frozenset(),
        insufficient_for: set[int] = frozenset(),
    ):
        self.calls: list[int] = []
        self.args: list[tuple[int, str, list[str]]] = []
        self.fail_on_call = fail_on_call
        self.empty_for = empty_for
        self.insufficient_for = insufficient_for

    async def generate_cards(self, item_number, title, pages, *, effort="medium"):
        self.calls.append(item_number)
        self.args.append((item_number, title, pages))
        if self.fail_on_call is not None and len(self.calls) == self.fail_on_call:
            raise RuntimeError("Claude indisponible")
        if item_number in self.empty_for:
            return _result([], 50, 5)
        if item_number in self.insufficient_for:
            return _result([], 80, 8, insufficient_text=True)
        return _result([FlashCardData("classique", "B", f"Q{item_number} ?", f"R{item_number}")], 100, 10)


def _result(cards, input_tokens, output_tokens, *, insufficient_text=False):
    return CardGenResult(
        cards=cards,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        model="claude-sonnet-5",
        insufficient_text=insufficient_text,
        stop_reason="end_turn" if input_tokens else None,
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


@pytest.fixture
def sequential(monkeypatch):
    """Un item à la fois : pour les scénarios qui dépendent de l'ordre des appels."""
    monkeypatch.setattr(settings, "generation_concurrency", 1)


@pytest.fixture(autouse=True)
def storage(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    return tmp_path


async def _ready_job(pg_factory, drafts: dict[int, str | list[str]], *, college_status="ocr_complete", user=None):
    async with pg_factory() as db:
        user = user or await make_user(db)
        college = await make_college(db, user, status=college_status, ref_id=34)
        job = await make_job(db, college, status="ocr_complete")
        for n, text in drafts.items():
            await make_draft(db, job, n, text, None)
        await db.commit()
    return user, college, job


async def _usage(pg_factory):
    async with pg_factory() as s:
        rows = (await s.execute(select(ClaudeUsage).order_by(ClaudeUsage.created_at))).scalars().all()
    return [(r.kind, r.model, r.input_tokens, r.output_tokens, r.user_id, r.college_id, r.job_id) for r in rows]


async def _run(pg_factory, college, job, claude, **kw):
    return await run_generation(pg_factory, college.id, job.id, claude, progress=None, **kw)


async def test_generates_each_draft_and_publishes(pg_factory, notifications):
    user, college, job = await _ready_job(pg_factory, {304: "texte 304", 305: "texte 305"})
    claude = FakeClaude()
    result = await _run(pg_factory, college, job, claude)
    assert claude.calls == [304, 305]
    assert (result["added"], result["cards"], result["claude_calls"]) == (2, 2, 2)
    async with pg_factory() as s:
        j = await s.get(GenerationJob, job.id)
        assert (j.status, j.hash_shared) == ("generation_complete", False)
    # Une ligne claude_usage par appel facturé.
    assert await _usage(pg_factory) == [("generation", "claude-sonnet-5", 100, 10, user.id, college.id, job.id)] * 2
    assert notifications.sent == [("complete", 34, None)]  # premier import : message simple


async def test_passes_title_and_pages_and_stores_card_rang(pg_factory, notifications):
    _, college, job = await _ready_job(pg_factory, {304: ["page 1 de 304", "page 2 de 304"]})
    claude = FakeClaude()
    await _run(pg_factory, college, job, claude)
    # Pages de l'item redécoupées (séparateur « \f » dans item_texts) pour clean_for_prompt.
    assert claude.args == [(304, "Item 304", ["page 1 de 304", "page 2 de 304"])]
    async with pg_factory() as s:
        gen = (await s.execute(select(ItemGeneration))).scalar_one()
        assert json.loads(gen.cards_json) == [
            {"card_type": "classique", "rang": "B", "recto": "Q304 ?", "verso": "R304"}
        ]
        assert (await s.execute(select(FlashCard.recto))).scalars().all() == ["Q304 ?"]


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


async def test_error_midway_then_relaunch_does_not_repay(pg_factory, notifications, monkeypatch, sequential):
    user, college, job = await _ready_job(pg_factory, {301: "a", 302: "b", 303: "c"})
    monkeypatch.setattr(generation_worker, "async_session_factory", pg_factory)
    monkeypatch.setattr(generation_worker, "ClaudeClient", lambda: FakeClaude(fail_on_call=2))
    with pytest.raises(RuntimeError):
        await generation_worker.generate_college_cards({}, str(college.id), str(job.id), "x.pdf")
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "failed"
    # Job échoué : l'appel facturé avant l'erreur reste compté.
    assert await _usage(pg_factory) == [("generation", "claude-sonnet-5", 100, 10, user.id, college.id, job.id)]
    async with pg_factory() as s:
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


async def test_interruption_then_arq_retry_does_not_repay(pg_factory, notifications, monkeypatch, sequential):
    _, college, job = await _ready_job(pg_factory, {301: "a", 302: "b", 303: "c"})

    class Interrupting(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            if item_number == 302:
                raise asyncio.CancelledError()
            return await super().generate_cards(item_number, title, pages)

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
    assert [r[:4] for r in await _usage(pg_factory)] == [("generation", "claude-sonnet-5", 50, 5)]
    async with pg_factory() as s:
        assert (await s.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 0
        assert (await s.execute(select(func.count()).select_from(Item))).scalar_one() == 1


async def test_stop_between_items(pg_factory, notifications, sequential):
    _, college, job = await _ready_job(pg_factory, {301: "a", 302: "b"})

    class StopAfterFirst(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            r = await super().generate_cards(item_number, title, pages)
            async with pg_factory() as s:
                (await s.get(GenerationJob, job.id)).status = "failed"
                await s.commit()
            return r

    claude = StopAfterFirst()
    result = await _run(pg_factory, college, job, claude)
    assert result["error"] == "cancelled" and claude.calls == [301]
    # Import arrêté pendant l'appel : l'appel facturé reste compté.
    assert [r[:4] for r in await _usage(pg_factory)] == [("generation", "claude-sonnet-5", 100, 10)]
    async with pg_factory() as s:
        assert (await s.execute(select(func.count()).select_from(Item))).scalar_one() == 0


async def test_deleted_account_stops_generation(pg_factory, notifications, sequential):
    user, college, job = await _ready_job(pg_factory, {301: "a", 302: "b"})

    class DeleteAfterFirst(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            r = await super().generate_cards(item_number, title, pages)
            async with pg_factory() as s:
                await s.delete(await s.get(User, user.id))
                await s.commit()
            return r

    claude = DeleteAfterFirst()
    result = await _run(pg_factory, college, job, claude)
    assert result["error"] == "cancelled" and claude.calls == [301]
    # Compte supprimé pendant l'appel : l'appel reste compté, sans lien.
    assert await _usage(pg_factory) == [("generation", "claude-sonnet-5", 100, 10, None, None, None)]


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


async def test_progress_reported_per_item(pg_factory, notifications, sequential):
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


async def test_backfilled_college_reimport_calls_claude_zero_times(pg_factory, notifications, storage):
    """Scénario prod : collège antérieur au chantier 1 (fiches sans génération
    d'origine), rempli par backfill_content_store, puis réimport du même PDF."""
    from scripts.backfill_content_store import backfill_college

    async with pg_factory() as db:
        user = await make_user(db, monthly_reloads=1)
        college = await make_college(db, user, status="generation_complete", reload_count=1)
        old_job = await make_job(db, college, status="generation_complete")
        kept = {}
        for n in (304, 305):
            item = await make_item(db, college, n, text=None)
            kept[n] = (await make_card(db, item, recto=f"ancienne {n}", user_feedback="positive")).id
        await db.commit()
    write_pdf(storage, college, old_job)
    async with pg_factory() as db:
        await backfill_college(
            db,
            await db.get(College, college.id),
            processor=FakeProcessor(PAGES),
            detector=FakeDetector(),
            pdf_dir=storage,
        )
        await db.commit()
        job = await make_job(db, await db.get(College, college.id))
        await db.commit()
    write_pdf(storage, college, job)
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=FakeProcessor(PAGES), detector=FakeDetector())
    claude = FakeClaude()
    result = await _run(pg_factory, college, job, claude)

    assert claude.calls == []
    assert (result["unchanged"], result["changed"], result["quota_refunded"]) == (2, 0, True)
    async with pg_factory() as s:
        assert set((await s.execute(select(FlashCard.id))).scalars()) == set(kept.values())


async def test_empty_text_item_does_not_count_as_claude_call(pg_factory, notifications):
    _, college, job = await _ready_job(pg_factory, {304: "texte"}, college_status="generation_complete")

    class ZeroTokens(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            self.calls.append(item_number)
            return _result([], 0, 0)

    result = await _run(pg_factory, college, job, ZeroTokens())
    assert result["claude_calls"] == 0


async def test_rejected_publish_fails_job_and_keeps_content(pg_factory, notifications):
    async with pg_factory() as db:
        user = await make_user(db, monthly_reloads=1)
        college = await make_college(db, user, status="generation_complete", reload_count=1)
        for n in (301, 302, 303, 304):
            await make_card(db, await make_item(db, college, n, text=f"t{n}"))
        job = await make_job(db, college, status="ocr_complete")
        await make_draft(db, job, 999, "autre collège", None)
        await db.commit()
    result = await _run(pg_factory, college, job, FakeClaude())
    assert result["error"] == "rejected" and "Rien n'a été modifié" in result["message"]
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "failed"
        assert (await s.execute(select(func.count()).select_from(FlashCard))).scalar_one() == 4
        assert (await s.get(College, college.id)).reload_count == 0  # quota rendu
    assert notifications.sent[-1] == ("failed", 34, True)


# --- Chantier 4 : génération en parallèle, texte insuffisant -----------------------


async def _drafts_again(pg_factory, college, texts):
    """Nouvel import du même collège avec les mêmes textes d'items."""
    async with pg_factory() as db:
        job = await make_job(db, await db.get(College, college.id), status="ocr_complete")
        for n, t in texts.items():
            await make_draft(db, job, n, t, None)
        await db.commit()
    return job


async def test_items_generated_in_parallel_up_to_the_concurrency(pg_factory, notifications, monkeypatch):
    monkeypatch.setattr(settings, "generation_concurrency", 4)
    _, college, job = await _ready_job(pg_factory, {300 + n: f"texte {n}" for n in range(10)})

    class Slow(FakeClaude):
        active = peak = 0

        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            Slow.active += 1
            Slow.peak = max(Slow.peak, Slow.active)
            try:
                await asyncio.sleep(0.05)
                return await super().generate_cards(item_number, title, pages)
            finally:
                Slow.active -= 1

    seen = []

    async def progress(college_id, **kw):
        seen.append((kw["items_done"], kw["cards"], list(kw["preview"])))

    claude = Slow()
    result = await run_generation(pg_factory, college.id, job.id, claude, progress=progress)
    assert Slow.peak == 4
    assert sorted(claude.calls) == list(range(300, 310))
    assert (result["added"], result["cards"], result["claude_calls"]) == (10, 10, 10)
    assert len(await _usage(pg_factory)) == 10
    # Avancement publié par le seul orchestrateur après chaque lot d'items terminés :
    # strictement croissant, cohérent (1 fiche par item) et complet à la fin.
    steps = [(done, cards) for done, cards, _ in seen]
    assert steps[0] == (0, 0) and steps[-1] == (10, 10)
    assert all(a < b for (a, _), (b, _) in zip(steps, steps[1:], strict=False))
    assert all(done == cards for done, cards in steps)
    assert len(seen[-1][2]) == 3


async def test_stop_cancels_in_flight_calls_and_keeps_committed_items(pg_factory, notifications, monkeypatch):
    monkeypatch.setattr(settings, "generation_concurrency", 2)
    texts = {n: f"texte {n}" for n in range(301, 307)}
    _, college, job = await _ready_job(pg_factory, texts)
    in_flight_303 = asyncio.Event()
    cancelled: list[int] = []

    class StopDuring(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            if item_number == 303:
                self.calls.append(item_number)
                in_flight_303.set()
                try:
                    await asyncio.sleep(30)
                except asyncio.CancelledError:
                    cancelled.append(item_number)
                    raise
            if item_number == 302:
                await asyncio.wait_for(in_flight_303.wait(), 5)
                async with pg_factory() as s:  # Stop pendant l'appel de 302 (303 en vol)
                    (await s.get(GenerationJob, job.id)).status = "failed"
                    await s.commit()
            return await super().generate_cards(item_number, title, pages)

    claude = StopDuring()
    result = await asyncio.wait_for(_run(pg_factory, college, job, claude), 10)
    assert result["error"] == "cancelled"
    assert sorted(claude.calls) == [301, 302, 303] and cancelled == [303]
    # Appels terminés comptés et générations conservées ; l'appel annulé n'a rien rendu.
    assert len(await _usage(pg_factory)) == 2
    async with pg_factory() as s:
        assert (await s.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 2

    # L'import est relancé : seuls les items non générés repassent par Claude.
    job2 = await _drafts_again(pg_factory, college, texts)
    claude = FakeClaude()
    result = await _run(pg_factory, college, job2, claude)
    assert sorted(claude.calls) == [303, 304, 305, 306]
    assert (result["added"], result["cards"], result["claude_calls"]) == (6, 6, 4)


async def test_api_error_fails_job_and_cancels_other_calls(pg_factory, notifications, monkeypatch):
    monkeypatch.setattr(settings, "generation_concurrency", 3)
    _, college, job = await _ready_job(pg_factory, {301: "a", 302: "b", 303: "c"})
    others_in_flight = asyncio.Event()
    cancelled: list[int] = []

    class ApiDown(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            self.calls.append(item_number)
            if item_number == 302:
                await asyncio.wait_for(others_in_flight.wait(), 5)
                # Erreur d'API restée après les réessais du SDK.
                raise anthropic.APIConnectionError(request=httpx.Request("POST", "https://api.anthropic.com"))
            if {301, 303} <= set(self.calls):
                others_in_flight.set()
            try:
                await asyncio.sleep(30)
            except asyncio.CancelledError:
                cancelled.append(item_number)
                raise
            raise AssertionError("jamais atteint")

    monkeypatch.setattr(generation_worker, "async_session_factory", pg_factory)
    monkeypatch.setattr(generation_worker, "ClaudeClient", ApiDown)
    with pytest.raises(anthropic.APIConnectionError):
        await asyncio.wait_for(generation_worker.generate_college_cards({}, str(college.id), str(job.id), "x.pdf"), 10)
    assert sorted(cancelled) == [301, 303]
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "failed"
        assert (await s.get(College, college.id)).status == "failed"
    assert notifications.sent == [("failed", 34, False)]


async def test_insufficient_item_is_listed_and_never_repaid(pg_factory, notifications):
    texts = {304: "vrai contenu", 305: "sommaire seul"}
    _, college, job = await _ready_job(pg_factory, texts)
    result = await _run(pg_factory, college, job, FakeClaude(insufficient_for={305}))
    assert (result["insufficient_items"], result["added"], result["cards"]) == ([305], 2, 1)
    assert [r[2:4] for r in await _usage(pg_factory)].count((80, 8)) == 1  # appel payé, compté
    async with pg_factory() as s:
        gens = (await s.execute(select(ItemGeneration))).scalars().all()
        assert sorted(g.insufficient_text for g in gens) == [False, True]

    # Réimport du même PDF : l'item insuffisant n'est pas retenté (0 appel) et reste signalé.
    job2 = await _drafts_again(pg_factory, college, texts)
    claude = FakeClaude(insufficient_for={305})
    result = await _run(pg_factory, college, job2, claude)
    assert claude.calls == []
    assert (result["insufficient_items"], result["claude_calls"], result["unchanged"]) == ([305], 0, 2)


async def test_modified_item_turned_insufficient_survives_purge_and_is_not_repaid(pg_factory, notifications):
    from app.services.content.purge import purge_unreferenced_content

    _, college, job = await _ready_job(pg_factory, {304: "ancien texte"})
    await _run(pg_factory, college, job, FakeClaude())
    # Le texte de l'item change et devient insuffisant : l'ancien contenu est gardé, la
    # nouvelle génération (0 fiche) n'est référencée par rien après la bascule.
    job2 = await _drafts_again(pg_factory, college, {304: "texte tronqué"})
    result = await _run(pg_factory, college, job2, FakeClaude(insufficient_for={304}))
    assert (result["insufficient_items"], result["cards"]) == ([304], 1)
    async with pg_factory() as db:
        await purge_unreferenced_content(db)
        await db.commit()
    job3 = await _drafts_again(pg_factory, college, {304: "texte tronqué"})
    claude = FakeClaude(insufficient_for={304})
    result = await _run(pg_factory, college, job3, claude)
    assert claude.calls == [] and result["insufficient_items"] == [304]


async def test_cancellation_right_after_the_call_still_persists_it(pg_factory, notifications, sequential):
    texts = {301: "a", 302: "b", 303: "c"}
    _, college, job = await _ready_job(pg_factory, texts)

    class CancelledAfterCall(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            r = await super().generate_cards(item_number, title, pages)
            if item_number == 302:
                asyncio.current_task().cancel()  # annulation livrée dès l'await suivant
            return r

    with pytest.raises(asyncio.CancelledError):
        await _run(pg_factory, college, job, CancelledAfterCall())
    # L'appel payé de 302 est enregistré (usage + génération) malgré l'annulation.
    assert len(await _usage(pg_factory)) == 2
    async with pg_factory() as s:
        assert (await s.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 2
        assert (await s.get(GenerationJob, job.id)).status == "ocr_complete"
    claude = FakeClaude()
    result = await _run(pg_factory, college, job, claude)  # relance ARQ du même job
    assert claude.calls == [303] and result["added"] == 3


async def test_cancellation_twice_still_persists_it(pg_factory, notifications, sequential, monkeypatch):
    """Revue tâche 6 (durcissement différé) : une deuxième annulation pendant la
    persistance ne doit pas laisser l'appel payé non enregistré."""
    texts = {301: "a", 302: "b", 303: "c"}
    _, college, job = await _ready_job(pg_factory, texts)
    persisting = asyncio.Event()
    release = asyncio.Event()
    original_persist = pipeline._persist_item
    cancel_again_task: asyncio.Task | None = None

    async def slow_persist(*args, **kwargs):
        if kwargs.get("item_number") == 302:
            persisting.set()
            await release.wait()  # laisse le temps à la deuxième annulation d'arriver
        return await original_persist(*args, **kwargs)

    monkeypatch.setattr(pipeline, "_persist_item", slow_persist)

    class CancelledTwiceAfterCall(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            nonlocal cancel_again_task
            r = await super().generate_cards(item_number, title, pages)
            if item_number == 302:
                task = asyncio.current_task()
                task.cancel()  # première annulation, livrée au prochain await (le shield de persist)

                async def cancel_again():
                    await persisting.wait()  # persist a commencé mais n'a pas encore écrit
                    task.cancel()  # deuxième annulation, pendant l'attente protégée
                    release.set()

                cancel_again_task = asyncio.ensure_future(cancel_again())
            return r

    with pytest.raises(asyncio.CancelledError):
        await asyncio.wait_for(_run(pg_factory, college, job, CancelledTwiceAfterCall()), 5)
    assert cancel_again_task is not None
    await cancel_again_task  # déjà terminée (release.set() précède la fin du run) : on le vérifie proprement
    # L'appel payé de 302 est bien enregistré malgré la double annulation.
    assert len(await _usage(pg_factory)) == 2
    async with pg_factory() as s:
        assert (await s.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 2
        assert (await s.get(GenerationJob, job.id)).status == "ocr_complete"
    claude = FakeClaude()
    result = await _run(pg_factory, college, job, claude)  # relance ARQ du même job
    assert claude.calls == [303] and result["added"] == 3


def test_primary_failure_prefers_a_real_error_over_a_cancellation():
    """Revue tâche 6 (durcissement différé) : dans un lot où une tâche échoue
    vraiment et une autre est seulement annulée, la vraie erreur doit remonter
    (pour `fail_job`), quel que soit l'ordre des tâches dans le lot."""

    async def boom():
        raise RuntimeError("vraie erreur")

    async def stalls():
        await asyncio.sleep(30)

    async def _scenario():
        err_task = asyncio.create_task(boom())
        cancel_task = asyncio.create_task(stalls())
        await asyncio.sleep(0)  # laisse boom() s'exécuter et se terminer
        cancel_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await cancel_task
        assert err_task.done() and cancel_task.cancelled()

        for failed in ([cancel_task, err_task], [err_task, cancel_task]):
            primary = pipeline._primary_failure(failed)
            assert primary is err_task
        assert isinstance(err_task.exception(), RuntimeError)  # retirée : pas de warning asyncio

    asyncio.run(_scenario())


async def test_every_task_error_is_logged(pg_factory, notifications, monkeypatch, caplog):
    monkeypatch.setattr(settings, "generation_concurrency", 2)
    _, college, job = await _ready_job(pg_factory, {301: "a", 302: "b"})
    both_in_flight = asyncio.Event()

    class BothFail(FakeClaude):
        async def generate_cards(self, item_number, title, pages, *, effort="medium"):
            self.calls.append(item_number)
            if len(self.calls) == 2:
                both_in_flight.set()
            await asyncio.wait_for(both_in_flight.wait(), 5)
            raise RuntimeError(f"panne {item_number}")

    with pytest.raises(RuntimeError) as raised:
        await _run(pg_factory, college, job, BothFail())
    other = ({"panne 301", "panne 302"} - {str(raised.value)}).pop()
    assert other in caplog.text
