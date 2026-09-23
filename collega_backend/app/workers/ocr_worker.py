"""Worker ARQ : OCR d'un PDF de collège (chantier 1).

Chaque page extraite est stockée une seule fois par empreinte (`ocr_pages`) et
rattachée à l'import (`job_pages`) : une reprise après interruption repart de la
dernière page faite. Les items détectés sont écrits dans le brouillon de l'import
(`job_items`) — le contenu en service (`items`, `flash_cards`) n'est touché qu'à
la bascule, après la génération. Un réimport laisse donc le collège consultable.
"""
from __future__ import annotations

import asyncio
import json
import logging
import uuid

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.database import async_session_factory
from app.models.college import College, CollegeStatus
from app.models.content import JobItem, JobPage
from app.models.generation_job import GenerationJob
from app.services.content import store
from app.services.jobs.job_events import record_job_event
from app.services.jobs.job_failure import fail_job
from app.services.ocr.confidence_scorer import ConfidenceScorer
from app.services.ocr.item_detector import DetectedItem, ItemDetector
from app.services.ocr.item_titles import lookup_title, record_title
from app.services.ocr.ocr_processor import OcrProcessor

logger = logging.getLogger(__name__)

_ocr_processor = OcrProcessor()
_RANG_PRIORITY: dict[str, int] = {"A": 0, "B": 1, "C": 2}  # A > B > C
_confidence_scorer = ConfidenceScorer()
_item_detector = ItemDetector()


async def process_college_ocr(ctx: dict, college_id: str, job_id: str, pdf_path: str) -> dict:
    """Tâche ARQ. Toute sortie anormale — y compris l'annulation par timeout ARQ
    (CancelledError) — passe l'import en échec sans toucher au contenu en service."""
    job_uuid = uuid.UUID(job_id)
    try:
        return await run_ocr(async_session_factory, uuid.UUID(college_id), job_uuid, pdf_path, ctx=ctx)
    except BaseException as exc:
        logger.exception("OCR failed for college %s: %r", college_id, exc)
        await fail_job(async_session_factory, job_uuid, f"OCR : {exc!r}"[:500])
        raise


async def _job_status(db: AsyncSession, job_id: uuid.UUID) -> str | None:
    return (
        await db.execute(select(GenerationJob.status).where(GenerationJob.id == job_id))
    ).scalar_one_or_none()


async def run_ocr(
    session_factory: async_sessionmaker[AsyncSession],
    college_id: uuid.UUID,
    job_id: uuid.UUID,
    pdf_path: str,
    *,
    processor=None,
    detector=None,
    ctx: dict | None = None,
) -> dict:
    processor = processor or _ocr_processor
    detector = detector or _item_detector
    base = {"college_id": str(college_id), "job_id": str(job_id)}

    async with session_factory() as db:
        college = await db.get(College, college_id)
        job = await db.get(GenerationJob, job_id)
        if college is None or job is None or job.status not in ("pending", "processing"):
            logger.info("OCR job %s ignoré (état %s)", job_id, job.status if job else "absent")
            return {**base, "error": "invalid_job_state"}
        first_import = college.status != CollegeStatus.generation_complete

        total_pages = await asyncio.to_thread(processor.count_pages, pdf_path)
        if total_pages == 0:
            await fail_job(session_factory, job_id, "PDF vide ou illisible (0 page)")
            return {**base, "error": "empty_pdf"}

        done = (
            await db.execute(select(func.count()).select_from(JobPage).where(JobPage.job_id == job_id))
        ).scalar_one()
        college.total_pages = total_pages
        college.ocr_page_progress = done
        # Nouvel import : l'avancement de la génération précédente ne s'affiche plus (8.13).
        college.generation_items_done = 0
        college.generation_items_total = None
        college.generation_cards = 0
        college.generation_preview = None
        if first_import:
            college.status = CollegeStatus.processing
        job.status = "processing"
        await record_job_event(db, job.id, "ocr_started", total=total_pages)
        await db.commit()
        done_pages = set(
            (await db.execute(select(JobPage.page_number).where(JobPage.job_id == job_id))).scalars()
        )

    progress_step = max(1, total_pages // 20)
    logger.info("OCR college %s — %d pages (%d déjà faites)", college_id, total_pages, len(done_pages))

    for page_num in range(total_pages):
        if page_num in done_pages:
            continue
        async with session_factory() as db:
            status = await _job_status(db, job_id)
        if status != "processing":
            logger.info("OCR job %s arrêté (statut %s) avant la page %d", job_id, status, page_num + 1)
            return {**base, "error": "cancelled"}

        result = await asyncio.to_thread(processor.process_page, pdf_path, page_num)

        async with session_factory() as db:
            try:
                page_hash = await store.put_page(db, result.text, result.tables, result.confidence_score, result.method)
                db.add(JobPage(job_id=job_id, page_number=page_num, page_hash=page_hash))
                college = await db.get(College, college_id)
                if college is None:
                    return {**base, "error": "cancelled"}
                college.ocr_page_progress = len(done_pages) + 1
                if (page_num + 1) % progress_step == 0 or page_num + 1 == total_pages:
                    await record_job_event(db, job_id, "ocr_progress", page=page_num + 1, total=total_pages)
                await db.commit()
            except IntegrityError:
                # Collège ou compte supprimé pendant la page (FK) : arrêt propre, rien à relancer.
                await db.rollback()
                if await _job_status(db, job_id) is None:
                    return {**base, "error": "cancelled"}
                raise
        done_pages.add(page_num)

    async with session_factory() as db:
        if await _job_status(db, job_id) != "processing":
            return {**base, "error": "cancelled"}
        items = await _detect_items(db, job_id, detector)
        await record_job_event(db, job_id, "items_detected", message=f"{len(items)} items")
        for detected in items:
            text_hash = await store.put_item_text(db, detected.ocr_text)
            db.add(
                JobItem(
                    job_id=job_id,
                    item_number=detected.item_number,
                    rang=detected.rang,
                    chapter_title=await _resolve_title(db, college_id, detected),
                    start_page=detected.start_page,
                    end_page=detected.end_page,
                    ocr_confidence_score=detected.ocr_confidence_score,
                    low_confidence=_confidence_scorer.is_low_confidence(detected.ocr_confidence_score),
                    text_hash=text_hash,
                )
            )
        job = await db.get(GenerationJob, job_id)
        college = await db.get(College, college_id)
        if job is None or college is None:
            return {**base, "error": "cancelled"}
        job.status = "ocr_complete"
        if college.status != CollegeStatus.generation_complete:
            college.status = CollegeStatus.ocr_complete
        await record_job_event(db, job_id, "ocr_complete", message=f"{len(items)} items")
        await db.commit()
        logger.info("OCR complete for college %s — %d items détectés", college_id, len(items))

        if ctx and "redis" in ctx:
            try:
                gen_job = await ctx["redis"].enqueue_job("generate_college_cards", str(college_id), str(job_id), pdf_path)
                # GOTCHA Stop (Story 7.7) : arq_job_id doit pointer sur le job ARQ de
                # la génération, sinon Stop ne pourrait plus l'annuler.
                if gen_job is not None:
                    job.arq_job_id = gen_job.job_id
                    await db.commit()
            except Exception as exc:  # noqa: BLE001
                # Sans génération en file, l'import resterait ocr_complete : le cron
                # des jobs bloqués le passera en échec (et l'utilisatrice pourra relancer).
                logger.error("Failed to enqueue generation job for college %s: %s", college_id, exc)

    return {**base, "item_count": len(items), "total_pages": total_pages}


async def _detect_items(db: AsyncSession, job_id: uuid.UUID, detector) -> list[DetectedItem]:
    """Détection sur toutes les pages de l'import, relues depuis le stockage."""
    rows = (
        await db.execute(select(JobPage).where(JobPage.job_id == job_id).order_by(JobPage.page_number))
    ).scalars().all()
    pages = await store.load_pages(db, [r.page_hash for r in rows])
    texts = [pages[r.page_hash].text for r in rows]
    scores = [pages[r.page_hash].confidence for r in rows]
    tables = [json.loads(pages[r.page_hash].tables_json) for r in rows]
    return dedupe_items(detector.detect_items(texts, scores, tables))


def dedupe_items(detected_items: list[DetectedItem]) -> list[DetectedItem]:
    """Un item par numéro (edge case : même numéro sur deux sections du PDF) :
    l'occurrence au contenu le plus long ; à contenu égal, le meilleur rang (A > B > C)."""
    deduped: dict[int, DetectedItem] = {}
    for det in detected_items:
        prev = deduped.get(det.item_number)
        if prev is None or len(det.ocr_text) > len(prev.ocr_text):
            deduped[det.item_number] = det
        elif _RANG_PRIORITY.get(det.rang, 99) < _RANG_PRIORITY.get(prev.rang, 99):
            deduped[det.item_number] = DetectedItem(
                item_number=prev.item_number,
                rang=det.rang,
                chapter_title=prev.chapter_title,
                ocr_text=prev.ocr_text,
                start_page=prev.start_page,
                end_page=prev.end_page,
                ocr_confidence_score=prev.ocr_confidence_score,
            )
    if len(deduped) < len(detected_items):
        logger.info("Dedup: %d → %d items", len(detected_items), len(deduped))
    return list(deduped.values())


async def _resolve_title(db: AsyncSession, college_id: uuid.UUID, detected: DetectedItem) -> str | None:
    """Story 8.0 — cascade du titre d'un item.

    1. Titre extrait de l'en-tête (déjà filtré par le détecteur) → gardé et versé au
       référentiel partagé (qui complète au passage les items vides des autres collèges).
    2. Sinon libellé du référentiel pour ce numéro.
    3. Sinon NULL + warning ; l'item sera complété au prochain import qui fournit ce titre.
    Le référentiel est un bonus : une erreur de sa part ne doit jamais casser l'import.
    """
    number = detected.item_number
    if detected.chapter_title:
        try:
            # Point de sauvegarde : un échec du référentiel ne doit pas annuler la
            # transaction de l'import (brouillon d'items en cours d'écriture).
            async with db.begin_nested():
                await record_title(db, number, detected.chapter_title)
        except Exception:  # noqa: BLE001
            logger.exception("Référentiel item_titles : échec d'écriture pour l'item %d", number)
        return detected.chapter_title

    try:
        title = await lookup_title(db, number)
    except Exception:  # noqa: BLE001
        logger.exception("Référentiel item_titles : échec de lecture pour l'item %d", number)
        title = None
    if title:
        return title

    logger.warning("Item %d du collège %s sans titre (ni en-tête ni référentiel)", number, college_id)
    return None
