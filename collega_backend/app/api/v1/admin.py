"""Routes admin Phase 0 — pipeline OCR + monitoring + gestion utilisateurs (Story 1.4).

Toutes les routes sont protégées par HTTP Basic Auth.
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Response, UploadFile
from sqlalchemy import func, select
from sqlalchemy import update as sa_update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import async_session_factory, get_db
from app.core.security import hash_password
from app.deps import get_admin_user
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.models.item import Item
from app.models.user import User
from app.schemas.admin import (
    AdminCardsResponseWrapped,
    AdminFeedbackData,
    AdminFeedbackResponseWrapped,
    AdminFlashCardData,
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
    CreateUserRequest,
    CreateUserResponseWrapped,
    ItemOcrData,
    JobDetailData,
    JobDetailResponseWrapped,
    JobEventData,
    OverviewData,
    OverviewResponseWrapped,
    PertinenceByRang,
    PertinenceStats,
    ProcessCollegeResponse,
    ProcessCollegeResponseWrapped,
    QueueJobData,
    QueueResponse,
    ResetQuotaResponseWrapped,
    StopJobData,
    StopJobResponseWrapped,
    UsageByUserData,
    UsageData,
    UsageResponseWrapped,
    UserBetaData,
    UserCollegeSummary,
    UserDetailData,
    UserDetailResponseWrapped,
    UserJobSummary,
    UsersListResponseWrapped,
)
from app.services.content.purge import delete_college_pdfs, purge_unreferenced_content
from app.services.generation.token_cost import compute_cost_eur
from app.services.jobs.arq_control import abort_arq_job
from app.services.jobs.job_failure import fail_job

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

    # Vérifier qu'aucun job actif n'existe déjà (aligné sur l'index UNIQUE
    # partial créé par migration 012 : ('pending', 'processing', 'ocr_complete')).
    existing_job = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college_id)
        .where(GenerationJob.status.in_(["pending", "processing", "ocr_complete"]))
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
            detail={
                "code": "INVALID_FILE_TYPE",
                "message": "File must be a PDF (.pdf extension or application/pdf content-type)",
            },
        )

    # Lire le premier chunk et vérifier la signature binaire PDF
    first_chunk = await pdf.read(_CHUNK_SIZE)
    if not first_chunk.startswith(_PDF_MAGIC):
        raise HTTPException(
            status_code=422,
            detail={
                "code": "INVALID_FILE_TYPE",
                "message": "File does not appear to be a valid PDF (missing %PDF- signature)",
            },
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

    # Créer le GenerationJob en base. IntegrityError = race avec /v1/colleges/{ref_id}/import
    # détectée par l'index UNIQUE partial sur (college_id) WHERE status active (migration 012).
    job = GenerationJob(
        id=job_id,
        college_id=college_id,
        user_id=college.user_id,
        status="pending",
    )
    db.add(job)
    try:
        await db.commit()
        await db.refresh(job)
    except IntegrityError:
        await db.rollback()
        pdf_file_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=409,
            detail={"code": "JOB_IN_PROGRESS", "message": "An active job already exists for this college"},
        ) from None

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
        ) from exc
    finally:
        if pool is not None:
            await pool.close()

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

    now = datetime.now(UTC)
    jobs = []
    for job, college in rows:
        created = job.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=UTC)
        elapsed = (now - created).total_seconds()
        jobs.append(
            QueueJobData(
                job_id=str(job.id),
                college_id=str(job.college_id),
                status=job.status,
                college_ocr_page_progress=college.ocr_page_progress,
                college_total_pages=college.total_pages,
                card_count=job.card_count,
                elapsed_seconds=round(max(0.0, elapsed), 1),
                error_message=job.error_message,
            )
        )
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
            monthly_reloads_max=settings.monthly_reloads_max,
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
            monthly_reloads_max=settings.monthly_reloads_max,
        )
    )


# ── Story 7.6 — Création utilisateur admin (hard-blocker onboarding) ──────────


@router.post("/users", response_model=CreateUserResponseWrapped, status_code=201)
async def create_user(
    body: CreateUserRequest,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> CreateUserResponseWrapped:
    """Crée un compte utilisateur (réservé admin).

    Seul point d'entrée d'onboarding tant que `POST /v1/auth/register` reste 403.
    L'inscription publique n'est PAS réouverte : cette route est protégée par
    Basic Auth admin et ne réactive jamais le register public.
    """
    # id généré explicitement → réponse construite sans dépendre d'un refresh
    # post-commit (évite un 500 si le refresh échoue alors que l'user est créé).
    user = User(
        id=uuid.uuid4(),
        email=body.email.strip().lower(),
        hashed_password=hash_password(body.password),
        is_beta=body.is_beta,
    )
    db.add(user)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail={"code": "EMAIL_ALREADY_EXISTS", "message": "Un compte avec cet email existe déjà."},
        ) from None
    # Invariants d'un compte neuf : jamais abonné (RevenueCat le posera plus tard),
    # quota vierge. Pas de relecture nécessaire.
    return CreateUserResponseWrapped(
        data=UserBetaData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=False,
            monthly_reloads=0,
            monthly_reloads_max=settings.monthly_reloads_max,
        )
    )


@router.post("/users/{user_id}/reset-quota", response_model=ResetQuotaResponseWrapped)
async def reset_user_quota(
    user_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> ResetQuotaResponseWrapped:
    """Réinitialise le quota mensuel d'un utilisateur.

    `monthly_reloads = 0` + `monthly_reloads_reset_at = None` : la fenêtre sera
    ré-initialisée proprement au prochain réimport via la logique lazy de
    `colleges.py` (cohérent avec le hardening quota Story 7.2).
    """
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "USER_NOT_FOUND", "message": f"User {user_id} not found"},
        )
    # UPDATE atomique (pattern Story 7.2) : évite tout lost-update vs un réimport
    # concurrent qui incrémente monthly_reloads entre le read et le commit.
    # La réponse est construite à partir des valeurs connues post-reset
    # (monthly_reloads=0), sans relire l'objet.
    await db.execute(sa_update(User).where(User.id == user_id).values(monthly_reloads=0, monthly_reloads_reset_at=None))
    await db.commit()
    return ResetQuotaResponseWrapped(
        data=UserBetaData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=user.is_subscribed,
            monthly_reloads=0,
            monthly_reloads_max=settings.monthly_reloads_max,
        )
    )


@router.get("/users/{user_id}", response_model=UserDetailResponseWrapped)
async def get_user_detail(
    user_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> UserDetailResponseWrapped:
    """Détail d'un utilisateur : champs + ses collèges + ses generation_jobs."""
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "USER_NOT_FOUND", "message": f"User {user_id} not found"},
        )

    colleges_result = await db.execute(
        select(College).where(College.user_id == user_id).order_by(College.created_at.desc())
    )
    colleges = colleges_result.scalars().all()

    jobs_result = await db.execute(
        select(GenerationJob).where(GenerationJob.user_id == user_id).order_by(GenerationJob.created_at.desc())
    )
    jobs = jobs_result.scalars().all()

    return UserDetailResponseWrapped(
        data=UserDetailData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=user.is_subscribed,
            monthly_reloads=user.monthly_reloads,
            monthly_reloads_max=settings.monthly_reloads_max,
            monthly_reloads_reset_at=(
                user.monthly_reloads_reset_at.isoformat() if user.monthly_reloads_reset_at else None
            ),
            created_at=user.created_at.isoformat() if user.created_at else None,
            colleges=[
                UserCollegeSummary(
                    college_id=str(c.id),
                    college_ref_id=c.college_ref_id,
                    status=c.status,
                    reload_count=c.reload_count,
                    reload_count_max=settings.reload_count_max,
                )
                for c in colleges
            ],
            jobs=[
                UserJobSummary(
                    job_id=str(j.id),
                    college_id=str(j.college_id),
                    status=j.status,
                    card_count=j.card_count,
                    error_message=j.error_message,
                    created_at=j.created_at.isoformat() if j.created_at else None,
                )
                for j in jobs
            ],
        )
    )


# ── Story 7.6 — Overview KPI (point d'entrée console) ─────────────────────────

_JOB_STATUSES = ("pending", "processing", "ocr_complete", "generation_complete", "failed")


@router.get("/overview", response_model=OverviewResponseWrapped)
async def get_overview(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> OverviewResponseWrapped:
    """KPI d'accueil console : total users, jobs par statut, jobs failed."""
    users_total = await db.execute(select(func.count()).select_from(User))
    users_count = users_total.scalar_one()

    jobs_result = await db.execute(select(GenerationJob.status, func.count()).group_by(GenerationJob.status))
    counts = {status: count for status, count in jobs_result.all()}
    jobs_by_status = {status: counts.get(status, 0) for status in _JOB_STATUSES}

    return OverviewResponseWrapped(
        data=OverviewData(
            users_total=users_count,
            jobs_by_status=jobs_by_status,
            jobs_failed=jobs_by_status["failed"],
        )
    )


# ── Story 7.7 — Suivi & contrôle des imports (timeline / détail / stop / delete) ─

_ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")


@router.get("/jobs/{job_id}", response_model=JobDetailResponseWrapped)
async def get_job_detail(
    job_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> JobDetailResponseWrapped:
    """Détail brut d'un job + timeline persistée + confiance OCR par item.

    Permet de débugger un import (distinguer mauvais OCR vs mauvais prompt) sans
    fouiller Redis/psql/logs NAS.
    """
    job = await db.get(GenerationJob, job_id)
    if job is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "JOB_NOT_FOUND", "message": f"Job {job_id} not found"},
        )

    college = await db.get(College, job.college_id)

    # Timeline : events ordonnés par date de création croissante (lisible au refresh)
    events_result = await db.execute(
        select(GenerationJobEvent)
        .where(GenerationJobEvent.generation_job_id == job_id)
        .order_by(GenerationJobEvent.created_at.asc())
    )
    events = events_result.scalars().all()

    # Confiance OCR par item (réutilise le schéma ItemOcrData, cf. get_college_stats)
    items_result = await db.execute(
        select(Item.item_number, Item.ocr_confidence_score, Item.low_confidence)
        .where(Item.college_id == job.college_id)
        .order_by(Item.item_number)
    )
    items = [ItemOcrData(item_number=r[0], ocr_confidence_score=r[1], low_confidence=r[2]) for r in items_result.all()]

    return JobDetailResponseWrapped(
        data=JobDetailData(
            job_id=str(job.id),
            college_id=str(job.college_id),
            user_id=str(job.user_id),
            status=job.status,
            arq_job_id=job.arq_job_id,
            pdf_hash=job.pdf_hash,
            hash_shared=job.hash_shared,
            card_count=job.card_count,
            error_message=job.error_message,
            created_at=job.created_at.isoformat() if job.created_at else None,
            updated_at=job.updated_at.isoformat() if job.updated_at else None,
            ocr_page_progress=college.ocr_page_progress if college else 0,
            total_pages=college.total_pages if college else None,
            college_status=college.status if college else "unknown",
            input_tokens=job.input_tokens,
            output_tokens=job.output_tokens,
            cost_eur=compute_cost_eur(job.input_tokens, job.output_tokens),
            items=items,
            timeline=[
                JobEventData(
                    event_type=e.event_type,
                    message=e.message,
                    page=e.page,
                    total=e.total,
                    created_at=e.created_at.isoformat() if e.created_at else None,
                )
                for e in events
            ],
        )
    )


@router.post("/jobs/{job_id}/stop", response_model=StopJobResponseWrapped)
async def stop_job(
    job_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> StopJobResponseWrapped:
    """Annule un job ARQ actif et force son statut DB à 'failed'.

    L'abort ARQ est best-effort (le worker ne catche pas CancelledError) : c'est
    l'endpoint qui est seul garant du statut DB. Réutiliser `failed` (et non un
    `cancelled`) évite d'altérer la CheckConstraint et libère l'index UNIQUE
    partiel (migration 012) → un réimport redevient possible. Décision PL 2026-06-17.
    """
    job = await db.get(GenerationJob, job_id)
    if job is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "JOB_NOT_FOUND", "message": f"Job {job_id} not found"},
        )
    if job.status not in _ACTIVE_JOB_STATUSES:
        raise HTTPException(
            status_code=409,
            detail={"code": "JOB_NOT_ACTIVE", "message": "Job is not active — nothing to cancel"},
        )

    # Abort ARQ best-effort. L'arq_job_id pointe toujours sur le job ARQ actif
    # (OCR puis génération, cf. fix persistance dans ocr_worker). On REMONTE le
    # résultat (review 7.7 D2) : sans cela l'admin croit avoir stoppé alors que
    # l'abort a pu échouer silencieusement (Redis down, flag worker absent) et que
    # le worker tourne encore. Le statut DB est forcé indépendamment du résultat.
    aborted = False
    if job.arq_job_id:
        aborted = await abort_arq_job(job.arq_job_id)

    # Échec centralisé (chantier 1) : brouillon vidé, PDF de l'import supprimé,
    # contenu en service du collège intact, utilisatrice notifiée.
    await fail_job(async_session_factory, job.id, "Annulé par l'admin", event="cancelled")
    await db.refresh(job)

    return StopJobResponseWrapped(
        data=StopJobData(
            job_id=str(job.id),
            status=job.status,
            error_message=job.error_message,
            aborted=aborted,
        )
    )


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
        .where(GenerationJob.status.in_(_ACTIVE_JOB_STATUSES))
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


@router.get("/usage", response_model=UsageResponseWrapped)
async def get_usage(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> UsageResponseWrapped:
    """Conso tokens Anthropic + coût € : total global + ventilation par user.

    Les jobs `NULL` (non mesurés, antérieurs migration 014) comptent comme 0 via
    `func.coalesce`. Le coût € est calculé à la lecture (jamais persisté).
    """
    global_result = await db.execute(
        select(
            func.coalesce(func.sum(GenerationJob.input_tokens), 0),
            func.coalesce(func.sum(GenerationJob.output_tokens), 0),
        )
    )
    g_input, g_output = global_result.one()

    by_user_result = await db.execute(
        select(
            User.id,
            User.email,
            func.coalesce(func.sum(GenerationJob.input_tokens), 0),
            func.coalesce(func.sum(GenerationJob.output_tokens), 0),
        )
        .join(GenerationJob, GenerationJob.user_id == User.id)
        .group_by(User.id, User.email)
        .order_by(User.email)
    )
    by_user = [
        UsageByUserData(
            user_id=str(uid),
            email=email,
            input_tokens=u_input,
            output_tokens=u_output,
            cost_eur=compute_cost_eur(u_input, u_output),
        )
        for uid, email, u_input, u_output in by_user_result.all()
    ]

    return UsageResponseWrapped(
        data=UsageData(
            input_tokens=g_input,
            output_tokens=g_output,
            cost_eur=compute_cost_eur(g_input, g_output),
            by_user=by_user,
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
