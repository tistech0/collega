"""Routes admin Phase 0 — pipeline OCR + monitoring + gestion utilisateurs (Story 1.4).

Toutes les routes sont protégées par HTTP Basic Auth.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.deps import get_admin_user
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.tester_feedback import TesterFeedback
from app.models.user import User
from app.schemas.admin import (
    BetaUpdateRequest,
    BetaUpdateResponseWrapped,
    CollegeStatsData,
    CollegeStatsResponseWrapped,
    CollegeStatusData,
    CollegeStatusResponseWrapped,
    ConfigData,
    ConfigResponseWrapped,
    ConfigUpdateRequest,
    CreateCollegeData,
    CreateCollegeRequest,
    CreateCollegeResponseWrapped,
    ItemOcrData,
    PertinenceByRang,
    PertinenceStats,
    ProcessCollegeResponse,
    ProcessCollegeResponseWrapped,
    QueueJobData,
    QueueResponse,
    UserBetaData,
    UsersListResponseWrapped,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["admin"])

_PDF_MAGIC = b"%PDF-"
_CHUNK_SIZE = 1024 * 1024  # 1 MB — évite de charger l'intégralité du fichier en mémoire


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

    # Vérifier qu'aucun job actif (pending ou processing) n'existe déjà
    existing_job = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college_id)
        .where(GenerationJob.status.in_(["pending", "processing"]))
    )
    if existing_job.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail={"code": "JOB_IN_PROGRESS", "message": "An active job already exists for this college"},
        )

    # Valider le type de fichier : content-type OU extension .pdf requis
    is_pdf = (pdf.content_type == "application/pdf") or (pdf.filename or "").lower().endswith(".pdf")
    if not is_pdf:
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_FILE_TYPE", "message": "File must be a PDF (.pdf extension or application/pdf content-type)"},
        )

    # Lire le premier chunk et vérifier la signature binaire PDF
    first_chunk = await pdf.read(_CHUNK_SIZE)
    if not first_chunk.startswith(_PDF_MAGIC):
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_FILE_TYPE", "message": "File does not appear to be a valid PDF (missing %PDF- signature)"},
        )

    # Sauvegarder le PDF en chunks pour éviter de tout charger en mémoire
    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)

    job_id = uuid.uuid4()
    pdf_file_path = storage_path / f"{college_id}_{job_id}.pdf"

    with open(pdf_file_path, "wb") as f:
        f.write(first_chunk)
        while chunk := await pdf.read(_CHUNK_SIZE):
            f.write(chunk)

    logger.info("PDF saved for college %s at %s", college_id, pdf_file_path)

    # Créer le GenerationJob en base
    job = GenerationJob(
        id=job_id,
        college_id=college_id,
        user_id=college.user_id,
        status="pending",
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    # Enqueuer le job ARQ — si l'enqueue échoue, on rollback et retourne 503
    pool = None
    try:
        from arq import create_pool  # type: ignore[import]
        from app.core.redis import redis_settings as _redis_settings

        pool = await create_pool(_redis_settings)
        arq_job = await pool.enqueue_job(
            "process_college_ocr",
            str(college_id),
            str(job_id),
            str(pdf_file_path),
        )
        if arq_job is not None:
            job.arq_job_id = arq_job.job_id
            await db.commit()
        logger.info("OCR job %s enqueued for college %s", job_id, college_id)
    except Exception as exc:  # noqa: BLE001
        logger.error("Failed to enqueue OCR job: %s", exc)
        # Rollback complet : supprimer le job DB et le fichier PDF
        await db.delete(job)
        await db.commit()
        pdf_file_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=503,
            detail={"code": "QUEUE_UNAVAILABLE", "message": "Failed to enqueue OCR job — please retry"},
        )
    finally:
        if pool is not None:
            await pool.close()

    return ProcessCollegeResponseWrapped(
        data=ProcessCollegeResponse(job_id=str(job.id), status=job.status)
    )


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


# ── Story 1.4 — Queue dashboard ───────────────────────────────────────────────

@router.get("/queue", response_model=QueueResponse)
async def get_queue(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> QueueResponse:
    """Liste les 50 derniers GenerationJob avec progression OCR et stats."""
    result = await db.execute(
        select(GenerationJob, College)
        .join(College, GenerationJob.college_id == College.id)
        .order_by(GenerationJob.created_at.desc())
        .limit(50)
    )
    rows = result.all()

    now = datetime.now(timezone.utc)
    jobs = []
    for job, college in rows:
        created = job.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        elapsed = (now - created).total_seconds()
        jobs.append(QueueJobData(
            job_id=str(job.id),
            college_id=str(job.college_id),
            status=job.status,
            college_ocr_page_progress=college.ocr_page_progress,
            college_total_pages=college.total_pages,
            card_count=job.card_count,
            elapsed_seconds=round(max(0.0, elapsed), 1),
            error_message=job.error_message,
        ))
    return QueueResponse(data=jobs, total=len(jobs))


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
    card_count_by_rang = {"A": card_rang_counts.get("A", 0), "B": card_rang_counts.get("B", 0), "C": card_rang_counts.get("C", 0)}

    # OCR confidence par item
    items_result = await db.execute(
        select(Item.item_number, Item.ocr_confidence_score, Item.low_confidence)
        .where(Item.college_id == college_id)
        .order_by(Item.item_number)
    )
    items_rows = items_result.all()
    items_ocr = [
        ItemOcrData(item_number=r[0], ocr_confidence_score=r[1], low_confidence=r[2])
        for r in items_rows
    ]
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

    # Pertinence stats depuis tester_feedbacks (Story 1.5)
    fb_result = await db.execute(
        select(TesterFeedback, FlashCard.rang)
        .join(FlashCard, TesterFeedback.flash_card_id == FlashCard.id)
        .where(TesterFeedback.college_id == college_id)
    )
    fb_rows = fb_result.all()

    pertinence_stats = None
    if fb_rows:
        pertinence_by_rang: dict[str, dict[str, int]] = {
            "A": {"pertinent": 0, "not_pertinent": 0},
            "B": {"pertinent": 0, "not_pertinent": 0},
            "C": {"pertinent": 0, "not_pertinent": 0},
        }
        for fb, rang in fb_rows:
            if rang not in pertinence_by_rang:
                pertinence_by_rang[rang] = {"pertinent": 0, "not_pertinent": 0}
            if fb.is_pertinent:
                pertinence_by_rang[rang]["pertinent"] += 1
            else:
                pertinence_by_rang[rang]["not_pertinent"] += 1
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


# ── Story 1.4 — Gestion utilisateurs beta ────────────────────────────────────

@router.get("/users", response_model=UsersListResponseWrapped)
async def list_users(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> UsersListResponseWrapped:
    """Liste tous les utilisateurs avec leur statut beta et abonnement."""
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    users = result.scalars().all()
    user_data = [
        UserBetaData(
            user_id=str(u.id),
            email=u.email,
            is_beta=u.is_beta,
            is_subscribed=u.is_subscribed,
            monthly_reloads=u.monthly_reloads,
        )
        for u in users
    ]
    return UsersListResponseWrapped(data=user_data, total=len(user_data))


@router.patch("/users/{user_id}/beta", response_model=BetaUpdateResponseWrapped)
async def update_user_beta(
    user_id: uuid.UUID,
    body: BetaUpdateRequest,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> BetaUpdateResponseWrapped:
    """Active ou désactive le flag is_beta pour un utilisateur."""
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "USER_NOT_FOUND", "message": f"User {user_id} not found"},
        )
    user.is_beta = body.is_beta
    await db.commit()
    return BetaUpdateResponseWrapped(
        data=UserBetaData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=user.is_subscribed,
            monthly_reloads=user.monthly_reloads,
        )
    )


# ── Story 1.4 — Configuration anti-spam ──────────────────────────────────────

@router.get("/config", response_model=ConfigResponseWrapped)
async def get_config(
    _: bool = Depends(get_admin_user),
) -> ConfigResponseWrapped:
    """Retourne la configuration anti-spam actuelle."""
    return ConfigResponseWrapped(
        data=ConfigData(
            reload_count_max=settings.reload_count_max,
            monthly_reloads_max=settings.monthly_reloads_max,
        )
    )


@router.patch("/config", response_model=ConfigResponseWrapped)
async def update_config(
    body: ConfigUpdateRequest,
    _: bool = Depends(get_admin_user),
) -> ConfigResponseWrapped:
    """Met à jour la configuration anti-spam en mémoire (sans redémarrage)."""
    if body.reload_count_max is not None:
        settings.reload_count_max = body.reload_count_max
    if body.monthly_reloads_max is not None:
        settings.monthly_reloads_max = body.monthly_reloads_max
    return ConfigResponseWrapped(
        data=ConfigData(
            reload_count_max=settings.reload_count_max,
            monthly_reloads_max=settings.monthly_reloads_max,
        )
    )
