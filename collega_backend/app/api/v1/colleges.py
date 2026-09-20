"""Routes collèges utilisateur — FR7 (liste), FR8-FR9 (import PDF + SSE)."""
from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy import update as sa_update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import async_session_factory, get_db
from app.core.time_utils import next_month_reset as _next_month_reset
from app.deps import get_current_user, require_subscription
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.schemas.college import (
    CardsListResponseWrapped,
    CollegeStatusData,
    CollegeStatusResponseWrapped,
    CollegesListResponseWrapped,
    FlashCardData,
    ImportCollegeResponseData,
    ImportCollegeResponseWrapped,
    ItemSummaryData,
    ItemsListResponseWrapped,
    ReloadLimitsData,
    ReloadLimitsResponseWrapped,
    UserCollegeData,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["colleges"])


_PDF_MAGIC = b"%PDF-"
_CHUNK_SIZE = 1024 * 1024  # 1 MB
_MAX_PDF_SIZE = 500 * 1024 * 1024  # 500 MB
_SSE_MAX_DURATION = 3 * 3600  # 3h
_SSE_POLL_INTERVAL = 1.5  # s entre deux lectures DB
# Cloudflare / reverse proxies coupent une connexion silencieuse après ~100 s :
# on émet un commentaire SSE `: keep-alive` si aucun événement n'est parti depuis ce délai.
_SSE_HEARTBEAT_INTERVAL = 15.0


@router.get("/colleges", response_model=CollegesListResponseWrapped)
async def list_user_colleges(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollegesListResponseWrapped:
    """Retourne tous les collèges importés par l'utilisateur authentifié."""
    result = await db.execute(
        select(College).where(College.user_id == current_user.id)
    )
    colleges = result.scalars().all()

    if not colleges:
        return CollegesListResponseWrapped(data=[], total=0)

    college_ids = [c.id for c in colleges]
    count_result = await db.execute(
        select(FlashCard.college_id, FlashCard.rang, func.count(FlashCard.id))
        .where(FlashCard.college_id.in_(college_ids))
        .group_by(FlashCard.college_id, FlashCard.rang)
    )
    counts_by_college: dict[uuid.UUID, dict[str, int]] = {}
    for college_id, rang, count in count_result.all():
        counts_by_college.setdefault(college_id, {})[rang] = count

    data = [
        UserCollegeData(
            college_ref_id=college.college_ref_id,
            college_id=str(college.id),
            status=college.status,
            card_count_a=counts_by_college.get(college.id, {}).get("A", 0),
            card_count_b=counts_by_college.get(college.id, {}).get("B", 0),
            card_count_c=counts_by_college.get(college.id, {}).get("C", 0),
        )
        for college in colleges
    ]

    return CollegesListResponseWrapped(data=data, total=len(data))


@router.get("/colleges/{ref_id}/reload-limits", response_model=ReloadLimitsResponseWrapped)
async def get_college_reload_limits(
    ref_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ReloadLimitsResponseWrapped:
    """Retourne les quotas de reimport pour ce collège (lecture seule)."""
    result = await db.execute(
        select(College)
        .where(College.user_id == current_user.id)
        .where(College.college_ref_id == ref_id)
    )
    college = result.scalar_one_or_none()
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "Collège non trouvé"},
        )

    now = datetime.now(timezone.utc)
    is_month_reset = (
        current_user.monthly_reloads_reset_at is None
        or now >= current_user.monthly_reloads_reset_at
    )
    effective_monthly = 0 if is_month_reset else current_user.monthly_reloads
    monthly_reset_at = _next_month_reset(now) if is_month_reset else current_user.monthly_reloads_reset_at

    return ReloadLimitsResponseWrapped(
        data=ReloadLimitsData(
            college_reload_count=college.reload_count,
            college_reload_max=settings.reload_count_max,
            monthly_reloads=effective_monthly,
            monthly_max=settings.monthly_reloads_max,
            monthly_reset_at=monthly_reset_at.isoformat(),
        )
    )


@router.post(
    "/colleges/{ref_id}/import",
    response_model=ImportCollegeResponseWrapped,
    status_code=202,
)
async def import_college_pdf(
    ref_id: int,
    pdf: UploadFile,
    current_user: User = Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
) -> ImportCollegeResponseWrapped:
    """Soumet un PDF pour traitement OCR — crée le College si nécessaire."""
    if not (1 <= ref_id <= 39):
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_REF_ID", "message": "ref_id must be between 1 and 39"},
        )

    # Chercher ou créer le College
    result = await db.execute(
        select(College)
        .where(College.user_id == current_user.id)
        .where(College.college_ref_id == ref_id)
    )
    college = result.scalar_one_or_none()

    if college is None:
        college = College(user_id=current_user.id, college_ref_id=ref_id)
        db.add(college)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raise HTTPException(
                status_code=409,
                detail={"code": "JOB_IN_PROGRESS", "message": "Un import est déjà en cours pour ce collège"},
            )

    # Vérifier qu'aucun job actif n'existe (inclut ocr_complete : génération Claude en cours)
    existing_job = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college.id)
        .where(GenerationJob.status.in_(["pending", "processing", "ocr_complete"]))
    )
    if existing_job.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail={"code": "JOB_IN_PROGRESS", "message": "Un import est déjà en cours pour ce collège"},
        )

    # Quota checks pour les reimports uniquement (premier import = libre).
    # Atomique : UPDATE conditionnel avec RETURNING — pas de race read-then-check.
    if college.status == "generation_complete":
        now = datetime.now(timezone.utc)
        is_month_reset = (
            current_user.monthly_reloads_reset_at is None
            or now >= current_user.monthly_reloads_reset_at
        )

        # 1. Reset mensuel lazy (filet de sécurité — cron quotidien est la source défensive)
        if is_month_reset:
            current_user.monthly_reloads = 0
            current_user.monthly_reloads_reset_at = _next_month_reset(now)
            await db.flush()

        # 2. Incrément atomique College.reload_count
        college_update = await db.execute(
            sa_update(College)
            .where(College.id == college.id)
            .where(College.reload_count < settings.reload_count_max)
            .values(reload_count=College.reload_count + 1)
            .returning(College.reload_count)
        )
        new_college_count = college_update.scalar_one_or_none()
        if new_college_count is None:
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "COLLEGE_RELOAD_LIMIT",
                    "message": f"Ce collège ne peut plus être retraité (limite : {settings.reload_count_max})",
                    "reload_count": college.reload_count,
                    "reload_count_max": settings.reload_count_max,
                },
            )

        # 3. Incrément atomique User.monthly_reloads — rollback college si échec
        user_update = await db.execute(
            sa_update(User)
            .where(User.id == current_user.id)
            .where(User.monthly_reloads < settings.monthly_reloads_max)
            .values(monthly_reloads=User.monthly_reloads + 1)
            .returning(User.monthly_reloads)
        )
        new_monthly = user_update.scalar_one_or_none()
        if new_monthly is None:
            # Annule l'incrément college fait juste avant (transaction non commitée)
            await db.rollback()
            reset_at = current_user.monthly_reloads_reset_at or _next_month_reset(now)
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "MONTHLY_RELOAD_LIMIT",
                    "message": f"Limite mensuelle atteinte ({settings.monthly_reloads_max} reimports/mois)",
                    "monthly_reloads": current_user.monthly_reloads,
                    "monthly_max": settings.monthly_reloads_max,
                    "reset_at": reset_at.isoformat(),
                },
            )

    # Valider le type de fichier
    is_pdf = (pdf.content_type == "application/pdf") or (pdf.filename or "").lower().endswith(".pdf")
    if not is_pdf:
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_FILE_TYPE", "message": "Le fichier doit être un PDF"},
        )

    first_chunk = await pdf.read(_CHUNK_SIZE)
    if not first_chunk.startswith(_PDF_MAGIC):
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_FILE_TYPE", "message": "Le fichier ne semble pas être un PDF valide"},
        )

    # Sauvegarder le PDF
    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)

    job_id = uuid.uuid4()
    pdf_file_path = storage_path / f"{college.id}_{job_id}.pdf"

    total_size = len(first_chunk)
    try:
        with open(pdf_file_path, "wb") as f:
            f.write(first_chunk)
            while chunk := await pdf.read(_CHUNK_SIZE):
                total_size += len(chunk)
                if total_size > _MAX_PDF_SIZE:
                    raise HTTPException(
                        status_code=413,
                        detail={"code": "FILE_TOO_LARGE", "message": "Le PDF ne doit pas dépasser 500 MB"},
                    )
                f.write(chunk)
    except HTTPException:
        pdf_file_path.unlink(missing_ok=True)
        raise

    logger.info("PDF saved for college %s (ref_id=%s) at %s", college.id, ref_id, pdf_file_path)

    # Créer le GenerationJob — nettoyer le PDF si le commit échoue.
    # IntegrityError = race OCR détectée par l'index UNIQUE partial sur (college_id) WHERE status active.
    job = GenerationJob(
        id=job_id,
        college_id=college.id,
        user_id=current_user.id,
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
            detail={"code": "JOB_IN_PROGRESS", "message": "Un import est déjà en cours pour ce collège"},
        )
    except Exception:
        pdf_file_path.unlink(missing_ok=True)
        raise

    # Enqueuer le job ARQ
    pool = None
    try:
        from arq import create_pool  # type: ignore[import]
        from app.core.redis import redis_settings as _redis_settings

        pool = await create_pool(_redis_settings)
        arq_job = await pool.enqueue_job(
            "process_college_ocr",
            str(college.id),
            str(job_id),
            str(pdf_file_path),
        )
        if arq_job is not None:
            job.arq_job_id = arq_job.job_id
            await db.commit()
        logger.info("OCR job %s enqueued for college %s", job_id, college.id)
    except Exception as exc:  # noqa: BLE001
        logger.error("Failed to enqueue OCR job: %s", exc)
        await db.delete(job)
        await db.commit()
        pdf_file_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=503,
            detail={"code": "QUEUE_UNAVAILABLE", "message": "Impossible d'enqueuer le job OCR — réessayez"},
        )
    finally:
        if pool is not None:
            await pool.close()

    return ImportCollegeResponseWrapped(
        data=ImportCollegeResponseData(
            college_id=str(college.id),
            job_id=str(job_id),
            status="pending",
        )
    )


@router.get(
    "/colleges/{college_id}/status",
    response_model=CollegeStatusResponseWrapped,
)
async def get_college_status(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollegeStatusResponseWrapped:
    """Retourne le statut OCR d'un collège appartenant à l'utilisateur."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    latest_job_result = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college_id)
        .order_by(GenerationJob.created_at.desc())
        .limit(1)
    )
    latest_job = latest_job_result.scalar_one_or_none()

    return CollegeStatusResponseWrapped(
        data=CollegeStatusData(
            college_id=str(college.id),
            ref_id=college.college_ref_id,
            status=college.status,
            ocr_page_progress=college.ocr_page_progress,
            total_pages=college.total_pages,
            job_id=str(latest_job.id) if latest_job else None,
        )
    )


@router.get("/colleges/{college_id}/stream")
async def stream_college_progress(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """Stream SSE de progression OCR pour un collège appartenant à l'utilisateur."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    async def event_generator():  # type: ignore[return]
        last_progress = -1
        ocr_complete_emitted = False
        loop = asyncio.get_event_loop()
        start_time = loop.time()
        last_emit = start_time

        try:
            while True:
                now = loop.time()
                if now - start_time > _SSE_MAX_DURATION:
                    break

                async with async_session_factory() as session:
                    c = await session.get(College, college_id)

                if c is None:
                    break

                if c.ocr_page_progress != last_progress:
                    last_progress = c.ocr_page_progress
                    event = {"event": "ocr_progress", "data": {"page": last_progress, "total": c.total_pages}}
                    yield f"data: {json.dumps(event)}\n\n"
                    last_emit = now

                if c.status == "ocr_complete" and not ocr_complete_emitted:
                    ocr_complete_emitted = True
                    event = {"event": "card_generation_started", "data": {"college_id": str(college_id)}}
                    yield f"data: {json.dumps(event)}\n\n"
                    last_emit = now

                if c.status == "generation_complete":
                    event = {"event": "generation_complete", "data": {"college_id": str(college_id)}}
                    yield f"data: {json.dumps(event)}\n\n"
                    break

                if c.status == "failed":
                    event = {"event": "generation_failed", "data": {"college_id": str(college_id)}}
                    yield f"data: {json.dumps(event)}\n\n"
                    break

                if now - last_emit >= _SSE_HEARTBEAT_INTERVAL:
                    # Commentaire SSE (ignoré par les clients) — garde la connexion ouverte
                    # à travers Cloudflare / NPM pendant la génération Claude.
                    yield ": keep-alive\n\n"
                    last_emit = now

                await asyncio.sleep(_SSE_POLL_INTERVAL)

        except asyncio.CancelledError:
            pass  # Client déconnecté — normal

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


@router.get("/colleges/{college_id}/items", response_model=ItemsListResponseWrapped)
async def list_college_items(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ItemsListResponseWrapped:
    """Retourne tous les items d'un collège dont la génération est terminée."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "College not found"},
        )
    if college.status != "generation_complete":
        raise HTTPException(
            status_code=409,
            detail={"code": "GENERATION_NOT_COMPLETE", "message": "Generation not yet complete"},
        )

    items_result = await db.execute(
        select(Item).where(Item.college_id == college_id).order_by(Item.item_number)
    )
    items = items_result.scalars().all()
    if not items:
        return ItemsListResponseWrapped(data=[], total=0)

    item_ids = [i.id for i in items]
    counts_result = await db.execute(
        select(FlashCard.item_id, FlashCard.rang, func.count(FlashCard.id))
        .where(FlashCard.item_id.in_(item_ids))
        .group_by(FlashCard.item_id, FlashCard.rang)
    )
    counts: dict[uuid.UUID, dict[str, int]] = {}
    for item_id_row, rang, count in counts_result.all():
        counts.setdefault(item_id_row, {})[rang] = count

    data = [
        ItemSummaryData(
            id=str(item.id),
            item_number=item.item_number,
            rang=item.rang,
            chapter_title=item.chapter_title,
            ocr_confidence_score=item.ocr_confidence_score,
            low_confidence=item.low_confidence,
            card_count_a=counts.get(item.id, {}).get("A", 0),
            card_count_b=counts.get(item.id, {}).get("B", 0),
            card_count_c=counts.get(item.id, {}).get("C", 0),
        )
        for item in items
    ]
    return ItemsListResponseWrapped(data=data, total=len(data))


@router.get("/colleges/{college_id}/items/{item_id}/cards", response_model=CardsListResponseWrapped)
async def list_item_cards(
    college_id: uuid.UUID,
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CardsListResponseWrapped:
    """Retourne toutes les flashcards d'un item, triées rang ASC puis card_type ASC."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "College not found"},
        )
    if college.status != "generation_complete":
        raise HTTPException(
            status_code=409,
            detail={"code": "GENERATION_NOT_COMPLETE", "message": "Generation not yet complete"},
        )

    item = await db.get(Item, item_id)
    if item is None or item.college_id != college_id:
        raise HTTPException(
            status_code=404,
            detail={"code": "ITEM_NOT_FOUND", "message": "Item not found"},
        )

    cards_result = await db.execute(
        select(FlashCard)
        .where(FlashCard.item_id == item_id)
        .order_by(FlashCard.rang, FlashCard.card_type)
    )
    cards = cards_result.scalars().all()
    data = [
        FlashCardData(
            id=str(c.id),
            item_id=str(c.item_id),
            college_id=str(c.college_id),
            card_type=c.card_type,
            rang=c.rang,
            recto=c.recto,
            verso=c.verso,
            ocr_confidence_score=c.ocr_confidence_score,
            low_confidence=c.low_confidence,
        )
        for c in cards
    ]
    return CardsListResponseWrapped(data=data, total=len(data))
