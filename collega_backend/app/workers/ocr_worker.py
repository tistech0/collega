"""Worker ARQ pour le traitement OCR des PDFs de collèges médicaux.

Exécuté en tâche de fond par ARQ. Reprend depuis la dernière page en cas
d'interruption (NFR11). Les textes OCR accumulés sont stockés dans
generation_jobs.page_texts_json pour garantir une détection d'items correcte
sur le document complet, même en cas de reprise partielle.
"""
from __future__ import annotations

import asyncio
import json
import logging
import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import async_session_factory
from app.models.college import College, CollegeStatus
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.services.ocr.confidence_scorer import ConfidenceScorer
from app.services.ocr.item_detector import ItemDetector
from app.services.ocr.ocr_processor import OcrProcessor

logger = logging.getLogger(__name__)

_ocr_processor = OcrProcessor()
_confidence_scorer = ConfidenceScorer()
_item_detector = ItemDetector()


async def process_college_ocr(
    ctx: dict,
    college_id: str,
    job_id: str,
    pdf_path: str,
) -> dict:
    """Traite l'OCR d'un PDF de collège page par page avec reprise automatique.

    Args:
        ctx: contexte ARQ (contient redis pool)
        college_id: UUID du college à traiter
        job_id: UUID du GenerationJob associé
        pdf_path: chemin absolu vers le PDF uploadé
    """
    async with async_session_factory() as db:
        college = await db.get(College, uuid.UUID(college_id))
        if college is None:
            logger.error("College %s not found — aborting OCR job", college_id)
            return {"error": "college_not_found"}

        job = await db.get(GenerationJob, uuid.UUID(job_id))
        if job is None:
            logger.error("GenerationJob %s not found — aborting OCR job", job_id)
            return {"error": "job_not_found"}

        try:
            result = await _run_ocr(db, college, job, pdf_path)
            return result
        except Exception as exc:  # noqa: BLE001
            logger.exception("OCR failed for college %s: %s", college_id, exc)
            job.status = "failed"
            job.error_message = str(exc)
            college.status = CollegeStatus.failed
            await db.commit()
            raise


async def _run_ocr(
    db: AsyncSession,
    college: College,
    job: GenerationJob,
    pdf_path: str,
) -> dict:
    # 1. Charger les textes déjà accumulés (reprise après interruption)
    previous_texts: list[str] = []
    previous_scores: list[float] = []
    if job.page_texts_json:
        stored = json.loads(job.page_texts_json)
        previous_texts = stored.get("texts", [])
        previous_scores = stored.get("scores", [])

    # La reprise est déterminée par les textes déjà stockés, pas par ocr_page_progress
    # Cela garantit que la détection d'items opère toujours sur le document complet
    start_page = len(previous_texts)

    # 2. Compter les pages totales (opération bloquante — exécutée dans thread pool)
    total_pages = await asyncio.to_thread(_ocr_processor.count_pages, pdf_path)

    if total_pages == 0:
        logger.warning("Empty or unreadable PDF for college %s — aborting", college.id)
        job.status = "failed"
        job.error_message = "PDF is empty or unreadable (0 pages detected)"
        college.status = CollegeStatus.failed
        await db.commit()
        return {"college_id": str(college.id), "job_id": str(job.id), "error": "empty_pdf"}

    college.total_pages = total_pages
    college.status = CollegeStatus.processing
    college.ocr_page_progress = start_page
    job.status = "processing"
    await db.commit()

    logger.info(
        "Starting OCR for college %s — %d pages (resuming from page %d)",
        college.id,
        total_pages,
        start_page,
    )

    # 3. Boucle OCR page par page (opérations bloquantes dans thread pool)
    page_texts: list[str] = list(previous_texts)
    page_scores: list[float] = list(previous_scores)

    for page_num in range(start_page, total_pages):
        page_result = await asyncio.to_thread(
            _ocr_processor.process_page, pdf_path, page_num
        )
        page_texts.append(page_result.text)
        page_scores.append(page_result.confidence_score)

        # Persiste la progression + les textes pour permettre une reprise correcte (NFR11)
        college.ocr_page_progress = page_num + 1
        job.page_texts_json = json.dumps({"texts": page_texts, "scores": page_scores})
        await db.commit()

        logger.debug(
            "OCR page %d/%d done (score=%.2f)",
            page_num + 1,
            total_pages,
            page_result.confidence_score,
        )

    # 4. Supprimer les items existants avant réinsertion (gestion des retries ARQ)
    await db.execute(delete(Item).where(Item.college_id == college.id))

    # 5. Détecter les items ECNi sur le document complet (toutes les pages, y compris les reprises)
    detected_items = _item_detector.detect_items(page_texts, page_scores)
    logger.info("Detected %d items in college %s", len(detected_items), college.id)

    # 6. Insérer les items en base
    for detected in detected_items:
        item_score = detected.ocr_confidence_score
        item = Item(
            college_id=college.id,
            item_number=detected.item_number,
            rang=detected.rang,
            chapter_title=detected.chapter_title or "",
            ocr_text=detected.ocr_text,
            ocr_confidence_score=item_score,
            low_confidence=_confidence_scorer.is_low_confidence(item_score),
            start_page=detected.start_page,
            end_page=detected.end_page,
        )
        db.add(item)

    # 7. Nettoyage et statuts finaux
    job.page_texts_json = None  # données intermédiaires non nécessaires après completion
    college.status = CollegeStatus.ocr_complete
    job.status = "ocr_complete"
    await db.commit()

    logger.info("OCR complete for college %s — %d items created", college.id, len(detected_items))
    return {
        "college_id": str(college.id),
        "job_id": str(job.id),
        "item_count": len(detected_items),
        "total_pages": total_pages,
    }
