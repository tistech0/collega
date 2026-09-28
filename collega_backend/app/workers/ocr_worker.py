"""Worker ARQ : OCR d'un PDF de collège (chantier 1).

Chaque page extraite est stockée une seule fois par empreinte (`ocr_pages`) et
rattachée à l'import (`job_pages`) : une reprise après interruption repart de la
dernière page faite. Les items détectés sont écrits dans le brouillon de l'import
(`job_items`) — le contenu en service (`items`, `flash_cards`) n'est touché qu'à
la bascule, après la génération. Un réimport laisse donc le collège consultable.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import uuid
from collections import Counter

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.database import async_session_factory
from app.models.college import College, CollegeStatus
from app.models.content import JobItem, JobPage
from app.models.generation_job import GenerationJob
from app.models.item_title import ItemTitle
from app.services.content import store
from app.services.jobs.job_events import record_job_event
from app.services.jobs.job_failure import fail_job
from app.services.ocr.confidence_scorer import ConfidenceScorer
from app.services.ocr.item_detector import DetectedItem, ItemDetector, SegmentationReport
from app.services.ocr.item_titles import lookup_title, record_title
from app.services.ocr.ocr_processor import OcrProcessor

logger = logging.getLogger(__name__)

_ocr_processor = OcrProcessor()
_confidence_scorer = ConfidenceScorer()
_LOGGED_WARNINGS = 20  # le rapport complet est dans generation_jobs.segmentation_report
NO_ITEMS_MESSAGE = "Aucun item détecté dans ce PDF"
_item_detector = ItemDetector()


async def process_college_ocr(ctx: dict, college_id: str, job_id: str, pdf_path: str) -> dict:
    """Tâche ARQ. Une erreur passe l'import en échec sans toucher au contenu en
    service. Une interruption (CancelledError : redéploiement, arrêt du worker) le
    laisse actif : ARQ le reprend au redémarrage depuis la dernière page faite ; s'il
    n'est jamais repris (timeout), le cron des jobs bloqués le passe en échec."""
    job_uuid = uuid.UUID(job_id)
    try:
        return await run_ocr(async_session_factory, uuid.UUID(college_id), job_uuid, pdf_path, ctx=ctx)
    except Exception as exc:
        logger.exception("OCR failed for college %s: %r", college_id, exc)
        await fail_job(async_session_factory, job_uuid, f"OCR : {exc!r}"[:500])
        raise


def file_sha256(path: str) -> str:
    """Empreinte du PDF (affichée par la console admin), lue par blocs."""
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


async def _job_status(db: AsyncSession, job_id: uuid.UUID) -> str | None:
    return (await db.execute(select(GenerationJob.status).where(GenerationJob.id == job_id))).scalar_one_or_none()


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

    early, total_pages, done_pages = await _begin_ocr(session_factory, college_id, job_id, pdf_path, processor, ctx)
    if early is not None:
        return {**base, **early}

    progress_step = max(1, total_pages // 20)
    logger.info("OCR college %s — %d pages (%d déjà faites)", college_id, total_pages, len(done_pages))

    for page_num in range(total_pages):
        if page_num in done_pages:
            continue
        stopped = await _ocr_page(
            session_factory,
            college_id,
            job_id,
            pdf_path,
            processor,
            page_num,
            total_pages,
            len(done_pages),
            progress_step,
        )
        if stopped is not None:
            return {**base, **stopped}
        done_pages.add(page_num)

    return {**base, **await _finish_ocr(session_factory, college_id, job_id, pdf_path, detector, ctx, total_pages)}


async def _begin_ocr(
    session_factory: async_sessionmaker[AsyncSession],
    college_id: uuid.UUID,
    job_id: uuid.UUID,
    pdf_path: str,
    processor,
    ctx: dict | None,
) -> tuple[dict | None, int, set[int]]:
    """Valide l'état du job et prépare le collège. Renvoie (résultat anticipé, nb de pages, pages déjà faites)."""
    async with session_factory() as db:
        college = await db.get(College, college_id)
        job = await db.get(GenerationJob, job_id)
        if college is not None and job is not None and job.status == "ocr_complete":
            # Reprise après une interruption survenue juste après la fin de l'OCR :
            # la génération n'a peut-être jamais été mise en file.
            await _enqueue_generation(db, job, pdf_path, ctx)
            return {"resumed": "generation_enqueued"}, 0, set()
        if college is None or job is None or job.status not in ("pending", "processing"):
            logger.info("OCR job %s ignoré (état %s)", job_id, job.status if job else "absent")
            return {"error": "invalid_job_state"}, 0, set()
        first_import = college.status != CollegeStatus.generation_complete

        total_pages = await asyncio.to_thread(processor.count_pages, pdf_path)
        if total_pages == 0:
            await fail_job(session_factory, job_id, "PDF vide ou illisible (0 page)")
            return {"error": "empty_pdf"}, 0, set()

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
        if job.pdf_hash is None:
            try:
                job.pdf_hash = await asyncio.to_thread(file_sha256, pdf_path)
            except OSError:
                logger.warning("Empreinte du PDF %s non calculée", pdf_path, exc_info=True)
        job.status = "processing"
        await record_job_event(db, job.id, "ocr_started", total=total_pages)
        await db.commit()
        done_pages = set((await db.execute(select(JobPage.page_number).where(JobPage.job_id == job_id))).scalars())
    return None, total_pages, done_pages


async def _ocr_page(
    session_factory: async_sessionmaker[AsyncSession],
    college_id: uuid.UUID,
    job_id: uuid.UUID,
    pdf_path: str,
    processor,
    page_num: int,
    total_pages: int,
    done_count: int,
    progress_step: int,
) -> dict | None:
    """OCR d'une page et enregistrement. Renvoie un résultat d'arrêt, ou None pour continuer."""
    async with session_factory() as db:
        status = await _job_status(db, job_id)
    if status != "processing":
        logger.info("OCR job %s arrêté (statut %s) avant la page %d", job_id, status, page_num + 1)
        return {"error": "cancelled"}

    result = await asyncio.to_thread(processor.process_page, pdf_path, page_num)

    async with session_factory() as db:
        try:
            page_hash = await store.put_page(db, result.text, result.tables, result.confidence_score, result.method)
            db.add(JobPage(job_id=job_id, page_number=page_num, page_hash=page_hash))
            college = await db.get(College, college_id)
            if college is None:
                return {"error": "cancelled"}
            college.ocr_page_progress = done_count + 1
            if (page_num + 1) % progress_step == 0 or page_num + 1 == total_pages:
                await record_job_event(db, job_id, "ocr_progress", page=page_num + 1, total=total_pages)
            await db.commit()
        except IntegrityError:
            # Collège ou compte supprimé pendant la page (FK) : arrêt propre, rien à relancer.
            await db.rollback()
            if await _job_status(db, job_id) is None:
                return {"error": "cancelled"}
            raise
    return None


async def _finish_ocr(
    session_factory: async_sessionmaker[AsyncSession],
    college_id: uuid.UUID,
    job_id: uuid.UUID,
    pdf_path: str,
    detector,
    ctx: dict | None,
    total_pages: int,
) -> dict:
    """Détecte les items, les enregistre et met la génération en file."""
    async with session_factory() as db:
        if await _job_status(db, job_id) != "processing":
            return {"error": "cancelled"}
        items, report = await _detect_items(db, job_id, detector)
        # Rapport de découpage (chantier 4) : numéros, sections, warnings — jamais de texte de page.
        logger.info("Découpage du job %s : %s", job_id, report.summary())
        if report.warnings:
            logger.warning("Découpage du job %s : %s", job_id, " ; ".join(report.warnings[:_LOGGED_WARNINGS]))
        message = _items_message(len(items), report)
        await record_job_event(db, job_id, "items_detected", message=message)
        if not items:
            # Rien à générer : échec propre, sans génération ni appel Claude.
            job = await db.get(GenerationJob, job_id)
            if job is not None:
                job.segmentation_report = report.to_json()
            await db.commit()
            await fail_job(session_factory, job_id, NO_ITEMS_MESSAGE)
            return {"error": "no_items"}
        for detected, pages in items:
            text_hash = await store.put_item_text(db, pages)
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
            return {"error": "cancelled"}
        job.status = "ocr_complete"
        job.segmentation_report = report.to_json()
        if college.status != CollegeStatus.generation_complete:
            college.status = CollegeStatus.ocr_complete
        await record_job_event(db, job_id, "ocr_complete", message=message)
        await db.commit()
        logger.info("OCR complete for college %s — %d items détectés", college_id, len(items))

        await _enqueue_generation(db, job, pdf_path, ctx)

    return {"item_count": len(items), "total_pages": total_pages}


def generation_arq_id(job_id: uuid.UUID) -> str:
    """Identifiant ARQ fixe de la génération d'un import : une remise en file
    (reprise de l'OCR) ne la duplique jamais."""
    return f"gen:{job_id}"


async def _enqueue_generation(db: AsyncSession, job: GenerationJob, pdf_path: str, ctx: dict | None) -> None:
    if not ctx or "redis" not in ctx:
        return
    try:
        await ctx["redis"].enqueue_job(
            "generate_college_cards", str(job.college_id), str(job.id), pdf_path, _job_id=generation_arq_id(job.id)
        )
        # GOTCHA Stop (Story 7.7) : arq_job_id doit pointer sur le job ARQ de la
        # génération, sinon Stop ne pourrait plus l'annuler.
        job.arq_job_id = generation_arq_id(job.id)
        await db.commit()
    except Exception as exc:  # noqa: BLE001
        # Sans génération en file, l'import resterait ocr_complete : le cron des
        # jobs bloqués le passera en échec (quota rendu) et l'utilisatrice relancera.
        logger.error("Failed to enqueue generation for job %s: %s", job.id, exc)


async def _detect_items(
    db: AsyncSession, job_id: uuid.UUID, detector
) -> tuple[list[tuple[DetectedItem, list[str]]], SegmentationReport]:
    """Découpage de toutes les pages de l'import, relues depuis le stockage.
    Renvoie chaque item avec le texte de ses pages (base de son empreinte), et le rapport."""
    rows = (
        (await db.execute(select(JobPage).where(JobPage.job_id == job_id).order_by(JobPage.page_number)))
        .scalars()
        .all()
    )
    pages = await store.load_pages(db, [r.page_hash for r in rows])
    texts = [pages[r.page_hash].text for r in rows]
    scores = [pages[r.page_hash].confidence for r in rows]
    tables = [json.loads(pages[r.page_hash].tables_json) for r in rows]
    result = detector.detect_items(texts, scores, tables, known_titles=await official_titles(db))
    return with_pages(result.items, texts), result.report


async def official_titles(db: AsyncSession) -> dict[int, str] | None:
    """Référentiel officiel des titres (`item_titles`, source `official`) ; None s'il est vide
    (le découpage n'en dépend pas, il restreint seulement les numéros sûrs)."""
    rows = (
        await db.execute(select(ItemTitle.item_number, ItemTitle.label).where(ItemTitle.source == "official"))
    ).all()
    return {number: label for number, label in rows} or None


def with_pages(items: list[DetectedItem], texts: list[str]) -> list[tuple[DetectedItem, list[str]]]:
    """Le texte d'un item est la concaténation de ses pages (`DetectedItem.pages`).

    Chapitre thématique (R11) dont les items ont exactement les mêmes pages : une 1re page
    « Item N » distingue leur texte. Sans elle, ils auraient la même empreinte et la
    génération du premier serait réutilisée telle quelle pour les autres (fiches en double)."""
    for d in items:
        if not d.pages:
            raise ValueError(f"Item {d.item_number} sans pages : découpage incohérent")
    same_pages = Counter(tuple(d.pages) for d in items)
    return [
        (d, ([f"Item {d.item_number}"] if same_pages[tuple(d.pages)] > 1 else []) + [texts[p] for p in d.pages])
        for d in items
    ]


def _items_message(count: int, report: SegmentationReport) -> str:
    """« 21 items, 3 avertissements de découpage » / « 1 item, … » (événements du job)."""
    warnings = len(report.warnings)
    return f"{count} item{'s' if count > 1 else ''}, {warnings} avertissement{'s' if warnings > 1 else ''} de découpage"


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
