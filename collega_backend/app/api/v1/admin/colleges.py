"""Routes admin — collèges : import, statut, stats, suppression, fiches et avis.

Toutes les routes sont protégées par HTTP Basic Auth.
"""

from __future__ import annotations

import logging
import uuid

from arq.connections import ArqRedis
from fastapi import APIRouter, Depends, HTTPException, Response, UploadFile
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_admin_user, get_arq
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.schemas.admin import (
    AdminCardsResponseWrapped,
    AdminFeedbackData,
    AdminFeedbackResponseWrapped,
    AdminFlashCardData,
    CollegeStatsData,
    CollegeStatsResponseWrapped,
    CollegeStatusData,
    CollegeStatusResponseWrapped,
    CreateCollegeData,
    CreateCollegeRequest,
    CreateCollegeResponseWrapped,
    ItemOcrData,
    PertinenceByRang,
    PertinenceStats,
    ProcessCollegeResponse,
    ProcessCollegeResponseWrapped,
)
from app.services import imports
from app.services.content.purge import delete_college_pdfs, purge_unreferenced_content

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/colleges", response_model=CreateCollegeResponseWrapped, status_code=201)
async def create_college(
    body: CreateCollegeRequest,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> CreateCollegeResponseWrapped:
    """Crée un nouveau collège pour un utilisateur existant."""
    user = await db.get(User, uuid.UUID(body.user_id))
    if user is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "USER_NOT_FOUND", "message": f"User {body.user_id} not found"},
        )
    college = College(user_id=user.id, college_ref_id=body.college_ref_id)
    db.add(college)
    await db.commit()
    await db.refresh(college)
    return CreateCollegeResponseWrapped(
        data=CreateCollegeData(
            college_id=str(college.id),
            user_id=str(college.user_id),
            college_ref_id=college.college_ref_id,
        )
    )


@router.post(
    "/colleges/{college_id}/process",
    response_model=ProcessCollegeResponseWrapped,
    status_code=202,
)
async def process_college(
    college_id: uuid.UUID,
    pdf: UploadFile,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    arq: ArqRedis = Depends(get_arq),
) -> ProcessCollegeResponseWrapped:
    """Soumet un PDF pour traitement OCR.

    Crée un GenerationJob avec statut 'pending' et enqueue le worker ARQ.
    Retourne 503 si Redis est indisponible — le job n'est pas créé.
    """
    # Valider que le college existe
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    await imports.assert_no_active_job(db, college)

    job_id = uuid.uuid4()
    pdf_file_path = imports.pdf_path_for(college_id, job_id)
    await imports.save_upload(pdf, pdf_file_path, max_size=None)
    logger.info("PDF saved for college %s at %s", college_id, pdf_file_path)

    job = await imports.create_job_and_enqueue(
        db, arq, college=college, user_id=college.user_id, job_id=job_id, pdf_path=pdf_file_path
    )
    return ProcessCollegeResponseWrapped(data=ProcessCollegeResponse(job_id=str(job.id), status=job.status))


@router.get(
    "/colleges/{college_id}/status",
    response_model=CollegeStatusResponseWrapped,
)
async def get_college_status(
    college_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> CollegeStatusResponseWrapped:
    """Retourne le statut OCR du college avec la progression par page."""
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    # Récupérer le dernier job
    latest_job_result = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college_id)
        .order_by(GenerationJob.created_at.desc())
        .limit(1)
    )
    latest_job = latest_job_result.scalar_one_or_none()

    return CollegeStatusResponseWrapped(
        data=CollegeStatusData(
            status=college.status,
            ocr_page_progress=college.ocr_page_progress,
            total_pages=college.total_pages,
            job_id=str(latest_job.id) if latest_job else None,
        )
    )


# ── Story 1.4 — Stats collège ─────────────────────────────────────────────────


@router.get("/colleges/{college_id}/stats", response_model=CollegeStatsResponseWrapped)
async def get_college_stats(
    college_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> CollegeStatsResponseWrapped:
    """Statistiques fiches par rang, scores OCR et hash-sharing pour un collège."""
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    # Compter les fiches par rang
    card_counts_result = await db.execute(
        select(FlashCard.rang, func.count(FlashCard.id))
        .where(FlashCard.college_id == college_id)
        .group_by(FlashCard.rang)
    )
    card_rang_counts = {row[0]: row[1] for row in card_counts_result.all()}
    card_count_by_rang = {
        "A": card_rang_counts.get("A", 0),
        "B": card_rang_counts.get("B", 0),
        "C": card_rang_counts.get("C", 0),
    }

    # OCR confidence par item
    items_result = await db.execute(
        select(Item.item_number, Item.ocr_confidence_score, Item.low_confidence)
        .where(Item.college_id == college_id)
        .order_by(Item.item_number)
    )
    items_rows = items_result.all()
    items_ocr = [ItemOcrData(item_number=r[0], ocr_confidence_score=r[1], low_confidence=r[2]) for r in items_rows]
    avg_confidence = sum(r[1] for r in items_rows) / len(items_rows) if items_rows else None

    # hash_shared depuis le dernier job generation_complete
    last_job_result = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college_id)
        .where(GenerationJob.status == "generation_complete")
        .order_by(GenerationJob.created_at.desc())
        .limit(1)
    )
    last_job = last_job_result.scalar_one_or_none()
    hash_shared = last_job.hash_shared if last_job else False

    # Pertinence depuis les avis de l'utilisatrice sur ses fiches (pouces du drill,
    # chantier 5 R3) : pertinent = positive, non pertinent = negative.
    fb_result = await db.execute(
        select(FlashCard.rang, FlashCard.user_feedback, func.count(FlashCard.id))
        .where(FlashCard.college_id == college_id)
        .where(FlashCard.user_feedback.is_not(None))
        .group_by(FlashCard.rang, FlashCard.user_feedback)
    )
    fb_rows = fb_result.all()

    pertinence_stats = None
    if fb_rows:
        pertinence_by_rang: dict[str, dict[str, int]] = {
            "A": {"pertinent": 0, "not_pertinent": 0},
            "B": {"pertinent": 0, "not_pertinent": 0},
            "C": {"pertinent": 0, "not_pertinent": 0},
        }
        for rang, feedback, count in fb_rows:
            if rang not in pertinence_by_rang:
                pertinence_by_rang[rang] = {"pertinent": 0, "not_pertinent": 0}
            key = "pertinent" if feedback == "positive" else "not_pertinent"
            pertinence_by_rang[rang][key] += count
        total_p = sum(v["pertinent"] for v in pertinence_by_rang.values())
        total_np = sum(v["not_pertinent"] for v in pertinence_by_rang.values())
        pertinence_stats = PertinenceStats(
            global_pertinent=total_p,
            global_not_pertinent=total_np,
            total_evaluated=total_p + total_np,
            by_rang={r: PertinenceByRang(**v) for r, v in pertinence_by_rang.items()},
        )

    return CollegeStatsResponseWrapped(
        data=CollegeStatsData(
            card_count_by_rang=card_count_by_rang,
            avg_ocr_confidence=round(avg_confidence, 4) if avg_confidence is not None else None,
            items_ocr_confidence=items_ocr,
            hash_shared=hash_shared,
            pertinence_stats=pertinence_stats,
        )
    )


# ── Story 7.7 — Suppression d'un import ──────────────────────────────────────


@router.delete("/colleges/{college_id}", status_code=204)
async def delete_college(
    college_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Supprime un import (college) et toute sa descendance + PDF disque.

    La suppression est au niveau College car FlashCard/Item n'ont aucune FK vers
    le GenerationJob — seul `DELETE College` emporte items/jobs/events/flashcards
    via la cascade ORM `all, delete-orphan` + FK `ondelete=CASCADE`.
    """
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    # Garde-fou symétrique au verrou de process_college (review 7.7 D3) : refuser
    # la suppression si un job est encore actif, sinon le worker en cours
    # commiterait sur des lignes supprimées (IntegrityError / orphelins). L'admin
    # doit d'abord arrêter l'import (POST /jobs/{id}/stop).
    active_job = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college_id)
        .where(GenerationJob.status.in_(imports.ACTIVE_JOB_STATUSES))
    )
    if active_job.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail={
                "code": "JOB_ACTIVE",
                "message": "An active job exists for this college — stop the import before deleting",
            },
        )

    await db.delete(college)
    await db.commit()

    # Cleanup PDF best-effort : ne jamais faire échouer la suppression DB pour un
    # problème disque. Plusieurs réimports ⇒ plusieurs PDFs ({college_id}_*.pdf).
    try:
        delete_college_pdfs(college_id)
        await purge_unreferenced_content(db)
        await db.commit()
    except Exception as exc:  # noqa: BLE001 — cleanup non bloquant (cron de nuit en filet)
        logger.warning("Cleanup failed for college %s: %s", college_id, exc)

    return Response(status_code=204)


# ── Story 7.8 — Qualité & Coût (inspection fiches / feedback / usage tokens) ──


@router.get("/colleges/{college_id}/cards", response_model=AdminCardsResponseWrapped)
async def get_college_cards(
    college_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> AdminCardsResponseWrapped:
    """Liste les fiches générées d'un collège (juger la qualité du prompt 7.5).

    `item_number` vient de l'Item parent (FlashCard n'a pas de colonne directe) via
    une jointure ; les scores OCR sont copiés sur la fiche à la génération.
    """
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    result = await db.execute(
        select(FlashCard, Item.item_number)
        .join(Item, FlashCard.item_id == Item.id)
        .where(FlashCard.college_id == college_id)
        .order_by(Item.item_number)
    )
    cards = [
        AdminFlashCardData(
            card_id=str(card.id),
            item_number=item_number,
            card_type=card.card_type,
            rang=card.rang,
            recto=card.recto,
            verso=card.verso,
            ocr_confidence_score=card.ocr_confidence_score,
            low_confidence=card.low_confidence,
        )
        for card, item_number in result.all()
    ]
    return AdminCardsResponseWrapped(data=cards, total=len(cards))


@router.get("/colleges/{college_id}/feedback", response_model=AdminFeedbackResponseWrapped)
async def get_college_feedback(
    college_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> AdminFeedbackResponseWrapped:
    """Avis de l'utilisatrice (pouces du drill, `flash_cards.user_feedback`) sur les
    fiches d'un collège, avec leur contenu, triés par numéro d'item.

    `is_pertinent=false` (avis négatif) = signal qualité n°1.
    """
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    result = await db.execute(
        select(FlashCard, Item.item_number, User.email)
        .join(Item, FlashCard.item_id == Item.id)
        .join(College, FlashCard.college_id == College.id)
        .join(User, College.user_id == User.id)
        .where(FlashCard.college_id == college_id)
        .where(FlashCard.user_feedback.is_not(None))
        .order_by(Item.item_number, FlashCard.created_at, FlashCard.id)
    )
    feedbacks = [
        AdminFeedbackData(
            flash_card_id=str(card.id),
            item_number=item_number,
            user_email=user_email,
            feedback=card.user_feedback,
            is_pertinent=card.user_feedback == "positive",
            recto=card.recto,
            verso=card.verso,
            card_type=card.card_type,
            rang=card.rang,
        )
        for card, item_number, user_email in result.all()
    ]
    return AdminFeedbackResponseWrapped(data=feedbacks, total=len(feedbacks))
