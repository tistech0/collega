"""Worker OCR (chantier 1) sur Postgres réel : pages par empreinte, reprise,
brouillon d'items, arrêt, échecs. OCR et détection simulés (contrôlés par les tests)."""

import asyncio
import json

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.college import College
from app.models.content import JobItem, JobPage, OcrPage
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.models.item import Item
from app.models.item_title import ItemTitle
from app.services.ocr.item_detector import DetectedItem, PageAssignment, SegmentationReport, SegmentationResult
from app.services.ocr.ocr_processor import OcrPageResult
from app.workers import ocr_worker
from app.workers.ocr_worker import run_ocr, with_pages
from tests.factories import make_college, make_item, make_job, make_user, write_pdf

pytestmark = pytest.mark.pg

PAGES = ["ITEM 304 Tumeurs du foie\ntexte A", "suite A\n233", "ITEM 305 Cancer du pancréas\ntexte B"]


class FakeProcessor:
    def __init__(self, pages, *, on_page=None):
        self.pages = pages
        self.calls: list[int] = []
        self.on_page = on_page

    def count_pages(self, path):
        return len(self.pages)

    def process_page(self, path, n):
        self.calls.append(n)
        if self.on_page:
            self.on_page(n)
        return OcrPageResult(page_num=n, text=self.pages[n], confidence_score=0.9, method="pdfplumber", tables=[])


class FakeRedis:
    def __init__(self):
        self.calls = []

    async def enqueue_job(self, name, *args, _job_id=None):
        self.calls.append((name, args, _job_id))
        return type("J", (), {"job_id": _job_id})()


class FakeDetector:
    """« ITEM n Titre » en tête de page ouvre un item jusqu'à la page suivante qui en ouvre un autre."""

    def __init__(self, titles=True):
        self.titles = titles
        self.known_titles = None

    def detect_items(self, texts, scores, tables, known_titles=None):
        self.known_titles = known_titles
        items, current = [], None
        for i, text in enumerate(texts):
            first = text.splitlines()[0]
            if first.startswith("ITEM "):
                number, title = first[5:].split(" ", 1)
                current = {"n": int(number), "title": title if self.titles else "", "start": i, "texts": []}
                items.append(current)
            if current:
                current["texts"].append(text)
                current["end"] = i
        detected = [
            DetectedItem(
                item_number=c["n"],
                rang="A",
                chapter_title=c["title"],
                ocr_text="\n".join(c["texts"]),
                start_page=c["start"],
                end_page=c["end"],
                ocr_confidence_score=0.9,
                pages=list(range(c["start"], c["end"] + 1)),
            )
            for c in items
        ]
        report = SegmentationReport(
            pages=[PageAssignment(p, "item", item_number=d.item_number) for d in detected for p in d.pages],
            items=[{"item_number": d.item_number, "pages": f"{d.start_page}-{d.end_page}"} for d in detected],
            warnings=["p9 : exemple"],
        )
        return SegmentationResult(items=detected, report=report)


@pytest.fixture
async def seed(pg_factory, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))

    async def _seed(college_status="pending"):
        async with pg_factory() as db:
            user = await make_user(db)
            college = await make_college(db, user, status=college_status)
            job = await make_job(db, college)
            await db.commit()
        write_pdf(tmp_path, college, job)
        return college, job

    return _seed


async def _count(pg_factory, model, **where):
    async with pg_factory() as s:
        q = select(func.count()).select_from(model)
        for k, v in where.items():
            q = q.where(getattr(model, k) == v)
        return (await s.execute(q)).scalar_one()


async def test_first_run_stores_pages_and_draft_items(pg_factory, seed, tmp_path):
    college, job = await seed()
    proc = FakeProcessor(PAGES)
    pdf = str(tmp_path / f"{college.id}_{job.id}.pdf")
    result = await run_ocr(pg_factory, college.id, job.id, pdf, processor=proc, detector=FakeDetector())

    assert result["item_count"] == 2 and proc.calls == [0, 1, 2]
    assert await _count(pg_factory, JobPage, job_id=job.id) == 3
    assert await _count(pg_factory, OcrPage) == 3
    assert await _count(pg_factory, Item) == 0  # rien en service avant la bascule
    async with pg_factory() as s:
        drafts = (await s.execute(select(JobItem).order_by(JobItem.item_number))).scalars().all()
        assert [(d.item_number, d.chapter_title, d.start_page, d.end_page) for d in drafts] == [
            (304, "Tumeurs du foie", 0, 1),
            (305, "Cancer du pancréas", 2, 2),
        ]
        j = await s.get(GenerationJob, job.id)
        assert j.status == "ocr_complete"
        assert j.pdf_hash == ocr_worker.file_sha256(pdf)
        c = await s.get(College, college.id)
        assert (c.status, c.total_pages, c.ocr_page_progress) == ("ocr_complete", 3, 3)


async def test_resume_skips_done_pages(pg_factory, seed):
    college, job = await seed()
    from app.services.content import store

    async with pg_factory() as s:
        h = await store.put_page(s, PAGES[0], [], 0.9, "pdfplumber")
        s.add(JobPage(job_id=job.id, page_number=0, page_hash=h))
        await s.get(GenerationJob, job.id)
        await s.commit()
    proc = FakeProcessor(PAGES)
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=proc, detector=FakeDetector())
    assert proc.calls == [1, 2]
    assert await _count(pg_factory, JobItem, job_id=job.id) == 2


async def test_reimport_keeps_college_ready_and_content_untouched(pg_factory, seed):
    college, job = await seed(college_status="generation_complete")
    async with pg_factory() as s:
        await make_item(s, await s.get(College, college.id), 304, text="ancien")
        await s.commit()
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=FakeProcessor(PAGES), detector=FakeDetector())
    async with pg_factory() as s:
        assert (await s.get(College, college.id)).status == "generation_complete"
    assert await _count(pg_factory, Item) == 1


async def test_duplicate_pages_stored_once(pg_factory, seed):
    college, job = await seed()
    pages = ["ITEM 304 Foie\nx", "blanc", "blanc"]
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=FakeProcessor(pages), detector=FakeDetector())
    assert await _count(pg_factory, OcrPage) == 2
    assert await _count(pg_factory, JobPage, job_id=job.id) == 3


async def test_stop_between_pages(pg_factory, seed, pg_engine):
    college, job = await seed()

    def stop_at_page_1(n):
        if n == 1:

            async def _stop():
                async with pg_factory() as s:
                    (await s.get(GenerationJob, job.id)).status = "failed"
                    await s.commit()

            asyncio.run_coroutine_threadsafe(_stop(), loop).result()

    loop = asyncio.get_running_loop()
    proc = FakeProcessor(PAGES, on_page=stop_at_page_1)
    result = await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=proc, detector=FakeDetector())
    assert result["error"] == "cancelled" and proc.calls == [0, 1]
    assert await _count(pg_factory, JobItem) == 0


async def test_deleted_job_stops_ocr(pg_factory, seed):
    college, job = await seed()

    def delete_job(n):
        if n == 0:

            async def _delete():
                async with pg_factory() as s:
                    await s.delete(await s.get(GenerationJob, job.id))
                    await s.commit()

            asyncio.run_coroutine_threadsafe(_delete(), loop).result()

    loop = asyncio.get_running_loop()
    proc = FakeProcessor(PAGES, on_page=delete_job)
    result = await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=proc, detector=FakeDetector())
    assert result["error"] == "cancelled" and proc.calls == [0]


async def test_empty_pdf_fails_first_import(pg_factory, seed):
    college, job = await seed()
    result = await run_ocr(
        pg_factory, college.id, job.id, "x.pdf", processor=FakeProcessor([]), detector=FakeDetector()
    )
    assert result["error"] == "empty_pdf"
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "failed"
        assert (await s.get(College, college.id)).status == "failed"


async def test_error_marks_job_failed_and_reraises(pg_factory, seed, monkeypatch):
    college, job = await seed()

    def boom(n):
        raise RuntimeError("pdfplumber KO")

    monkeypatch.setattr(ocr_worker, "async_session_factory", pg_factory)
    monkeypatch.setattr(ocr_worker, "_ocr_processor", FakeProcessor(PAGES, on_page=boom))
    with pytest.raises(RuntimeError):
        await ocr_worker.process_college_ocr({}, str(college.id), str(job.id), "x.pdf")
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "failed"
        assert (await s.get(College, college.id)).status == "failed"


async def test_interruption_keeps_job_resumable(pg_factory, seed, monkeypatch):
    """Redéploiement / arrêt du worker : le job reste actif, ARQ le reprend."""
    college, job = await seed()

    def interrupted(n):
        if n == 1:
            raise asyncio.CancelledError()

    monkeypatch.setattr(ocr_worker, "async_session_factory", pg_factory)
    monkeypatch.setattr(ocr_worker, "_ocr_processor", FakeProcessor(PAGES, on_page=interrupted))
    with pytest.raises(asyncio.CancelledError):
        await ocr_worker.process_college_ocr({}, str(college.id), str(job.id), "x.pdf")
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "processing"
    # Reprise par ARQ : repart de la page 1, termine l'OCR.
    proc = FakeProcessor(PAGES)
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=proc, detector=FakeDetector())
    assert proc.calls == [1, 2]
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).status == "ocr_complete"


async def test_finished_job_is_not_reprocessed(pg_factory, seed):
    college, job = await seed()
    async with pg_factory() as s:
        (await s.get(GenerationJob, job.id)).status = "generation_complete"
        await s.commit()
    proc = FakeProcessor(PAGES)
    result = await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=proc, detector=FakeDetector())
    assert result["error"] == "invalid_job_state" and proc.calls == []


async def test_generation_enqueued_and_stop_target_repointed(pg_factory, seed):
    college, job = await seed()

    redis = FakeRedis()
    await run_ocr(
        pg_factory,
        college.id,
        job.id,
        "x.pdf",
        processor=FakeProcessor(PAGES),
        detector=FakeDetector(),
        ctx={"redis": redis},
    )
    assert redis.calls == [("generate_college_cards", (str(college.id), str(job.id), "x.pdf"), f"gen:{job.id}")]
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, job.id)).arq_job_id == f"gen:{job.id}"


async def test_resumed_after_ocr_complete_reenqueues_generation(pg_factory, seed):
    """Interruption juste après la fin de l'OCR : la reprise remet la génération en
    file (identifiant ARQ fixe, jamais dupliquée) sans refaire l'OCR."""
    college, job = await seed()
    async with pg_factory() as s:
        (await s.get(GenerationJob, job.id)).status = "ocr_complete"
        await s.commit()
    redis, proc = FakeRedis(), FakeProcessor(PAGES)
    result = await run_ocr(
        pg_factory, college.id, job.id, "x.pdf", processor=proc, detector=FakeDetector(), ctx={"redis": redis}
    )
    assert result["resumed"] == "generation_enqueued" and proc.calls == []
    assert [c[2] for c in redis.calls] == [f"gen:{job.id}"]


async def test_title_cascade_uses_and_feeds_referential(pg_factory, seed):
    # Premier import : titres extraits → versés au référentiel.
    college, job = await seed()
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=FakeProcessor(PAGES), detector=FakeDetector())
    async with pg_factory() as s:
        labels = {t.item_number: t.label for t in (await s.execute(select(ItemTitle))).scalars()}
    assert labels == {304: "Tumeurs du foie", 305: "Cancer du pancréas"}
    # Import sans titre extrait : complété par le référentiel.
    college2, job2 = await seed()
    await run_ocr(
        pg_factory, college2.id, job2.id, "x.pdf", processor=FakeProcessor(PAGES), detector=FakeDetector(titles=False)
    )
    async with pg_factory() as s:
        drafts = (await s.execute(select(JobItem).where(JobItem.job_id == job2.id))).scalars().all()
        assert {d.item_number: d.chapter_title for d in drafts} == labels


def test_with_pages_uses_item_pages_not_a_range():
    """Chantier 4 : dedupe_items a disparu (R8 : un item par numéro, plages concaténées) ;
    le texte d'un item est celui de ses pages, même non contiguës."""
    item = DetectedItem(
        item_number=216,
        rang="A",
        chapter_title="t",
        ocr_text="",
        start_page=0,
        end_page=3,
        ocr_confidence_score=0.9,
        pages=[0, 1, 3],
    )
    assert with_pages([item], ["p0", "p1", "p2", "p3"]) == [(item, ["p0", "p1", "p3"])]


async def test_segmentation_report_is_stored_and_official_titles_passed(pg_factory, seed):
    college, job = await seed()
    async with pg_factory() as s:
        s.add(ItemTitle(item_number=304, label="Tumeurs du foie", source="official", occurrences=1))
        s.add(ItemTitle(item_number=305, label="Autre libellé extrait", source="extracted", occurrences=1))
        await s.commit()
    detector = FakeDetector()
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=FakeProcessor(PAGES), detector=detector)
    assert detector.known_titles == {304: "Tumeurs du foie"}
    async with pg_factory() as s:
        stored = (await s.get(GenerationJob, job.id)).segmentation_report
    data = json.loads(stored)
    assert [i["item_number"] for i in data["items"]] == [304, 305]
    assert data["warnings"] == ["p9 : exemple"]
    assert "texte A" not in stored


def test_with_pages_rejects_item_without_pages():
    item = DetectedItem(
        item_number=1, rang="A", chapter_title="", ocr_text="", start_page=0, end_page=0, ocr_confidence_score=0.9
    )
    with pytest.raises(ValueError):
        with_pages([item], ["p0"])


async def test_event_messages_carry_segmentation_warning_count(pg_factory, seed):
    college, job = await seed()
    await run_ocr(pg_factory, college.id, job.id, "x.pdf", processor=FakeProcessor(PAGES), detector=FakeDetector())
    async with pg_factory() as s:
        events = (
            await s.execute(
                select(GenerationJobEvent.event_type, GenerationJobEvent.message).where(
                    GenerationJobEvent.generation_job_id == job.id,
                    GenerationJobEvent.event_type.in_(["items_detected", "ocr_complete"]),
                )
            )
        ).all()
    assert sorted(events) == [
        ("items_detected", "2 items, 1 avertissement de découpage"),
        ("ocr_complete", "2 items, 1 avertissement de découpage"),
    ]


async def test_no_item_fails_the_job_without_generation(pg_factory, seed):
    """Découpage sans aucun item (même après le repli) : échec propre, rien en file, aucun coût."""
    college, job = await seed()
    redis = FakeRedis()
    result = await run_ocr(
        pg_factory,
        college.id,
        job.id,
        "x.pdf",
        processor=FakeProcessor(["Une page de texte sans aucun numéro d'item, assez longue."] * 3),
        ctx={"redis": redis},
    )
    assert result["error"] == "no_items"
    assert redis.calls == []
    async with pg_factory() as s:
        stored = await s.get(GenerationJob, job.id)
        assert (stored.status, stored.error_message) == ("failed", "Aucun item détecté dans ce PDF")
        assert "découpage suspect" in json.loads(stored.segmentation_report)["warnings"][-1]
        assert (await s.get(College, college.id)).status == "failed"
    assert await _count(pg_factory, JobItem, job_id=job.id) == 0
