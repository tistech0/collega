"""Routes collèges utilisateur — FR7 (liste), FR8-FR9 (import PDF + SSE)."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request, Response, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy import update as sa_update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import async_session_factory, get_db
from app.core.time_utils import next_month_reset as _next_month_reset
from app.deps import get_current_user, get_current_user_short_session, require_subscription
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.schemas.college import (
    CardsListResponseWrapped,
    CollegesListResponseWrapped,
    CollegeStatusData,
    CollegeStatusResponseWrapped,
    FlashCardData,
    ImportCollegeResponseData,
    ImportCollegeResponseWrapped,
    ItemsListResponseWrapped,
    ItemSummaryData,
    ReloadLimitsData,
    ReloadLimitsResponseWrapped,
    UploadInitData,
    UploadInitRequest,
    UploadInitResponseWrapped,
    UploadStatusData,
    UploadStatusResponseWrapped,
    UserCollegeData,
)
from app.services.ocr.pdf_check import assert_pdf_readable
from app.services.upload.chunked_upload import (
    MAX_UPLOAD_SIZE,
    ChunkedUploadStore,
    InvalidPartIndex,
    PartSizeError,
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
    result = await db.execute(select(College).where(College.user_id == current_user.id))
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
        select(College).where(College.user_id == current_user.id).where(College.college_ref_id == ref_id)
    )
    college = result.scalar_one_or_none()
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "Collège non trouvé"},
        )

    now = datetime.now(UTC)
    is_month_reset = current_user.monthly_reloads_reset_at is None or now >= current_user.monthly_reloads_reset_at
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


def _job_in_progress() -> HTTPException:
    return HTTPException(
        status_code=409,
        detail={"code": "JOB_IN_PROGRESS", "message": "Un import est déjà en cours pour ce collège"},
    )


def _invalid_ref_id(ref_id: int) -> None:
    if not (1 <= ref_id <= 39):
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_REF_ID", "message": "ref_id must be between 1 and 39"},
        )


async def _select_college(db: AsyncSession, user: User, ref_id: int) -> College | None:
    result = await db.execute(select(College).where(College.user_id == user.id).where(College.college_ref_id == ref_id))
    return result.scalar_one_or_none()


async def _get_or_create_college(db: AsyncSession, user: User, ref_id: int) -> College:
    college = await _select_college(db, user, ref_id)
    if college is None:
        college = College(user_id=user.id, college_ref_id=ref_id)
        db.add(college)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raise _job_in_progress() from None
    return college


async def _assert_no_active_job(db: AsyncSession, college: College) -> None:
    """Aucun job actif (inclut ocr_complete : génération Claude en cours)."""
    existing_job = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college.id)
        .where(GenerationJob.status.in_(["pending", "processing", "ocr_complete"]))
    )
    if existing_job.scalar_one_or_none() is not None:
        raise _job_in_progress()


def _college_reload_limit(college: College) -> HTTPException:
    return HTTPException(
        status_code=409,
        detail={
            "code": "COLLEGE_RELOAD_LIMIT",
            "message": f"Ce collège ne peut plus être retraité (limite : {settings.reload_count_max})",
            "reload_count": college.reload_count,
            "reload_count_max": settings.reload_count_max,
        },
    )


def _monthly_reload_limit(user: User, now: datetime) -> HTTPException:
    reset_at = user.monthly_reloads_reset_at or _next_month_reset(now)
    return HTTPException(
        status_code=409,
        detail={
            "code": "MONTHLY_RELOAD_LIMIT",
            "message": f"Limite mensuelle atteinte ({settings.monthly_reloads_max} reimports/mois)",
            "monthly_reloads": user.monthly_reloads,
            "monthly_max": settings.monthly_reloads_max,
            "reset_at": reset_at.isoformat(),
        },
    )


async def _apply_reimport_quota(db: AsyncSession, user: User, college: College) -> None:
    """Quota checks pour les reimports uniquement (premier import = libre).
    Atomique : UPDATE conditionnel avec RETURNING — pas de race read-then-check."""
    if college.status != "generation_complete":
        return

    now = datetime.now(UTC)
    is_month_reset = user.monthly_reloads_reset_at is None or now >= user.monthly_reloads_reset_at

    # 1. Reset mensuel lazy (filet de sécurité — cron quotidien est la source défensive)
    if is_month_reset:
        user.monthly_reloads = 0
        user.monthly_reloads_reset_at = _next_month_reset(now)
        await db.flush()

    # 2. Incrément atomique College.reload_count
    college_update = await db.execute(
        sa_update(College)
        .where(College.id == college.id)
        .where(College.reload_count < settings.reload_count_max)
        .values(reload_count=College.reload_count + 1)
        .returning(College.reload_count)
    )
    if college_update.scalar_one_or_none() is None:
        raise _college_reload_limit(college)

    # 3. Incrément atomique User.monthly_reloads — rollback college si échec
    user_update = await db.execute(
        sa_update(User)
        .where(User.id == user.id)
        .where(User.monthly_reloads < settings.monthly_reloads_max)
        .values(monthly_reloads=User.monthly_reloads + 1)
        .returning(User.monthly_reloads)
    )
    if user_update.scalar_one_or_none() is None:
        # Annule l'incrément college fait juste avant (transaction non commitée)
        await db.rollback()
        raise _monthly_reload_limit(user, now)


async def _assert_import_allowed(db: AsyncSession, user: User, ref_id: int) -> College | None:
    """Gardes d'import en lecture seule (aucune écriture) — utilisées par POST /import/init
    (morceaux) avant de recevoir le moindre octet. Renvoie le College existant ou None.
    Lève les mêmes HTTPException que le chemin d'import (422 INVALID_REF_ID, 409 JOB_IN_PROGRESS,
    409 COLLEGE_RELOAD_LIMIT / MONTHLY_RELOAD_LIMIT) ; le quota réel est consommé à `complete`."""
    _invalid_ref_id(ref_id)
    college = await _select_college(db, user, ref_id)
    if college is None:
        return None
    await _assert_no_active_job(db, college)

    if college.status == "generation_complete":
        now = datetime.now(UTC)
        month_reset_due = user.monthly_reloads_reset_at is None or now >= user.monthly_reloads_reset_at
        if college.reload_count >= settings.reload_count_max:
            raise _college_reload_limit(college)
        if not month_reset_due and user.monthly_reloads >= settings.monthly_reloads_max:
            raise _monthly_reload_limit(user, now)
    return college


async def _create_job_and_enqueue(
    db: AsyncSession, user: User, college: College, job_id: uuid.UUID, pdf_file_path: Path
) -> ImportCollegeResponseData:
    """Crée le GenerationJob et enqueue l'OCR. Supprime le PDF sur toute erreur."""
    # IntegrityError = race OCR détectée par l'index UNIQUE partial sur (college_id) WHERE status active.
    job = GenerationJob(
        id=job_id,
        college_id=college.id,
        user_id=user.id,
        status="pending",
    )
    db.add(job)
    try:
        await db.commit()
        await db.refresh(job)
    except IntegrityError:
        await db.rollback()
        pdf_file_path.unlink(missing_ok=True)
        raise _job_in_progress() from None
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
        ) from exc
    finally:
        if pool is not None:
            await pool.close()

    return ImportCollegeResponseData(
        college_id=str(college.id),
        job_id=str(job_id),
        status="pending",
    )


async def _start_import_from_file(
    db: AsyncSession, user: User, ref_id: int, pdf_file_path: Path
) -> ImportCollegeResponseData:
    """Chemin d'import à partir d'un PDF déjà écrit sur le volume partagé (upload par morceaux
    assemblé) : get/create College, garde job actif, quotas atomiques, renommage en
    `{college.id}_{job_id}.pdf` (convention attendue par la purge admin), GenerationJob + enqueue.
    Supprime le PDF sur toute erreur."""
    try:
        college = await _get_or_create_college(db, user, ref_id)
        await _assert_no_active_job(db, college)
        await _apply_reimport_quota(db, user, college)
    except HTTPException:
        pdf_file_path.unlink(missing_ok=True)
        raise

    job_id = uuid.uuid4()
    final_path = pdf_file_path.with_name(f"{college.id}_{job_id}.pdf")
    os.replace(pdf_file_path, final_path)
    logger.info("PDF ready for college %s (ref_id=%s) at %s", college.id, ref_id, final_path)
    return await _create_job_and_enqueue(db, user, college, job_id, final_path)


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
    """Soumet un PDF pour traitement OCR — crée le College si nécessaire (mono-requête, ≤ 100 MB
    derrière Cloudflare ; au-delà, voir /import/init)."""
    _invalid_ref_id(ref_id)
    college = await _get_or_create_college(db, current_user, ref_id)
    await _assert_no_active_job(db, college)
    await _apply_reimport_quota(db, current_user, college)

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

    try:
        await assert_pdf_readable(pdf_file_path)
    except HTTPException:
        # Quota (UPDATE non validé) annulé : un PDF endommagé ne coûte rien.
        pdf_file_path.unlink(missing_ok=True)
        await db.rollback()
        raise

    logger.info("PDF saved for college %s (ref_id=%s) at %s", college.id, ref_id, pdf_file_path)

    data = await _create_job_and_enqueue(db, current_user, college, job_id, pdf_file_path)
    return ImportCollegeResponseWrapped(data=data)


# ── Story 7.11 — upload par morceaux (Cloudflare : 100 MB max par requête) ──────


async def get_upload_store() -> AsyncIterator[ChunkedUploadStore]:
    """Store d'upload : Redis via le pool ARQ (redis.asyncio) + volume pdf_storage."""
    from arq import create_pool  # type: ignore[import]

    from app.core.redis import redis_settings as _redis_settings

    pool = await create_pool(_redis_settings)
    try:
        yield ChunkedUploadStore(pool, Path(settings.pdf_storage_path))
    finally:
        await pool.close()


def _upload_not_found() -> HTTPException:
    return HTTPException(
        status_code=404,
        detail={"code": "UPLOAD_NOT_FOUND", "message": "Upload inconnu ou expiré — relancer l'import"},
    )


@router.post(
    "/colleges/{ref_id}/import/init",
    response_model=UploadInitResponseWrapped,
    status_code=201,
)
async def init_chunked_import(
    ref_id: int,
    body: UploadInitRequest,
    current_user: User = Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> UploadInitResponseWrapped:
    """Ouvre un upload par morceaux. Mêmes gardes que POST /import, quota NON consommé."""
    await _assert_import_allowed(db, current_user, ref_id)
    if body.size_bytes > MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=413,
            detail={"code": "FILE_TOO_LARGE", "message": "Le PDF ne doit pas dépasser 500 MB"},
        )
    state = await store.create(current_user.id, ref_id, body.size_bytes)
    logger.info("Chunked upload %s opened (ref_id=%s, %d parts)", state.upload_id, ref_id, state.parts_total)
    return UploadInitResponseWrapped(
        data=UploadInitData(
            upload_id=state.upload_id,
            part_size=state.part_size,
            parts_total=state.parts_total,
            expires_at=state.expires_at.isoformat(),
        )
    )


@router.get("/colleges/import/{upload_id}", response_model=UploadStatusResponseWrapped)
async def get_chunked_import_status(
    upload_id: uuid.UUID,
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> UploadStatusResponseWrapped:
    """Morceaux déjà reçus — authentifié par l'upload_id seul (cf. spec §3.4)."""
    state = await store.get(str(upload_id))
    if state is None:
        raise _upload_not_found()
    return UploadStatusResponseWrapped(
        data=UploadStatusData(
            received=sorted(state.received),
            parts_total=state.parts_total,
            part_size=state.part_size,
            size_bytes=state.size_bytes,
            expires_at=state.expires_at.isoformat(),
        )
    )


@router.put("/colleges/import/{upload_id}/parts/{n}", status_code=204)
async def put_chunked_import_part(
    upload_id: uuid.UUID,
    n: int,
    request: Request,
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> Response:
    """Reçoit un morceau binaire brut (body = octets du morceau). Idempotent."""
    state = await store.get(str(upload_id))
    if state is None:
        raise _upload_not_found()
    try:
        await store.write_part(state, n, request.stream())
    except (PartSizeError, InvalidPartIndex) as exc:
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_PART", "message": f"Morceau invalide : {exc}"},
        ) from exc
    return Response(status_code=204)


@router.post(
    "/colleges/import/{upload_id}/complete",
    response_model=ImportCollegeResponseWrapped,
    status_code=202,
)
async def complete_chunked_import(
    upload_id: uuid.UUID,
    current_user: User = Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> ImportCollegeResponseWrapped:
    """Assemble les morceaux puis enchaîne sur le pipeline d'import existant."""
    state = await store.get(str(upload_id))
    if state is None or state.user_id != str(current_user.id):
        raise _upload_not_found()
    if not state.is_complete:
        raise HTTPException(
            status_code=409,
            detail={"code": "UPLOAD_INCOMPLETE", "message": "Morceaux manquants", "missing": state.missing},
        )
    with open(store.part_path(state.upload_id, 0), "rb") as f:
        if not f.read(len(_PDF_MAGIC)).startswith(_PDF_MAGIC):
            await store.claim(state.upload_id)
            store.purge(state.upload_id)
            raise HTTPException(
                status_code=422,
                detail={"code": "INVALID_FILE_TYPE", "message": "Le fichier ne semble pas être un PDF valide"},
            )

    # Prise de possession atomique : un complete concurrent qui perd le DEL reçoit 409.
    claimed = await store.claim(state.upload_id)
    if claimed is None:
        raise _job_in_progress()

    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)
    assembled = storage_path / f"incoming_{state.upload_id}.pdf"
    try:
        store.assemble(claimed, assembled)
        await assert_pdf_readable(assembled)
        data = await _start_import_from_file(db, current_user, claimed.ref_id, assembled)
    except HTTPException as exc:
        assembled.unlink(missing_ok=True)
        if exc.status_code == 503:
            # File indisponible : on garde les morceaux pour permettre un nouveau complete sans re-upload
            await store.restore(claimed)
        else:
            store.purge(claimed.upload_id)
        raise
    except Exception:
        assembled.unlink(missing_ok=True)
        await store.restore(claimed)
        raise

    store.purge(claimed.upload_id)
    logger.info("Chunked upload %s completed → college %s job %s", upload_id, data.college_id, data.job_id)
    return ImportCollegeResponseWrapped(data=data)


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

    latest_job = await _latest_job(db, college_id)
    return CollegeStatusResponseWrapped(data=_status_data(college, latest_job))


async def _latest_job(db: AsyncSession, college_id: uuid.UUID) -> GenerationJob | None:
    return (
        await db.execute(
            select(GenerationJob)
            .where(GenerationJob.college_id == college_id)
            .order_by(GenerationJob.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()


def _import_status(college: College, job: GenerationJob | None) -> str:
    """Statut de l'import en cours ou du dernier import (chantier 1) — le statut du
    collège, lui, décrit son contenu et reste `generation_complete` pendant un réimport."""
    return job.status if job is not None else college.status


def _job_summary(job: GenerationJob | None) -> dict | None:
    if job is None or job.status != "generation_complete" or not job.summary_json:
        return None
    try:
        value = json.loads(job.summary_json)
    except ValueError:
        return None
    # Le résumé ne concerne que les réimports (un premier import n'a rien « changé »).
    return value if isinstance(value, dict) and value.get("reimport") else None


def _is_failed_reimport(college: College, job: GenerationJob | None) -> bool:
    return job is not None and job.status == "failed" and college.status == "generation_complete"


def _status_data(college: College, job: GenerationJob | None) -> CollegeStatusData:
    return CollegeStatusData(
        college_id=str(college.id),
        ref_id=college.college_ref_id,
        status=_import_status(college, job),
        ocr_page_progress=college.ocr_page_progress,
        total_pages=college.total_pages,
        job_id=str(job.id) if job else None,
        summary=_job_summary(job),
        reimport=_is_failed_reimport(college, job),
    )


async def _poll_state(college_id: uuid.UUID) -> tuple[College | None, GenerationJob | None]:
    """Un sondage du flux SSE : session courte, rendue avant l'attente suivante."""
    async with async_session_factory() as session:
        college = await session.get(College, college_id)
        job = await _latest_job(session, college_id) if college is not None else None
        return college, job


def _preview(raw: str | None) -> list[str]:
    """Aperçu des dernières fiches (JSON en base) ; illisible → vide."""
    if not raw:
        return []
    try:
        value = json.loads(raw)
    except ValueError:
        return []
    return [q for q in value if isinstance(q, str)] if isinstance(value, list) else []


@router.get("/colleges/{college_id}/stream")
async def stream_college_progress(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user_short_session),
) -> StreamingResponse:
    """Stream SSE de progression d'un import (collège de l'utilisateur).

    Aucune connexion à la base n'est gardée pendant le flux : authentification et
    contrôle d'accès en sessions courtes, puis une session courte par sondage."""
    async with async_session_factory() as session:
        college = await session.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    async def event_generator():  # type: ignore[return]
        last_progress = -1
        last_generation: tuple[int, int, int, str | None] | None = None
        ocr_complete_emitted = False
        loop = asyncio.get_running_loop()
        start_time = loop.time()
        last_emit = start_time

        try:
            while True:
                now = loop.time()
                if now - start_time > _SSE_MAX_DURATION:
                    break

                c, job = await _poll_state(college_id)
                if c is None:
                    break
                status = _import_status(c, job)

                if c.ocr_page_progress != last_progress:
                    last_progress = c.ocr_page_progress
                    event = {"event": "ocr_progress", "data": {"page": last_progress, "total": c.total_pages}}
                    yield f"data: {json.dumps(event)}\n\n"
                    last_emit = now

                if status == "ocr_complete" and not ocr_complete_emitted:
                    ocr_complete_emitted = True
                    event = {"event": "card_generation_started", "data": {"college_id": str(college_id)}}
                    yield f"data: {json.dumps(event)}\n\n"
                    last_emit = now

                # Story 8.13 : fiches générées au fil des items (seulement pendant la génération).
                total = c.generation_items_total
                if status == "ocr_complete" and total is not None:
                    current = (c.generation_items_done, total, c.generation_cards, c.generation_preview)
                    if current != last_generation:
                        last_generation = current
                        event = {
                            "event": "generation_progress",
                            "data": {
                                "items_done": current[0],
                                "items_total": current[1],
                                "cards": current[2],
                                "preview": _preview(current[3]),
                            },
                        }
                        yield f"data: {json.dumps(event)}\n\n"
                        last_emit = now

                if status == "generation_complete":
                    data = {"college_id": str(college_id), "summary": _job_summary(job)}
                    yield f"data: {json.dumps({'event': 'generation_complete', 'data': data})}\n\n"
                    break

                if status == "failed":
                    data = {
                        "college_id": str(college_id),
                        "message": job.error_message if job is not None else None,
                        "reimport": _is_failed_reimport(c, job),
                    }
                    yield f"data: {json.dumps({'event': 'generation_failed', 'data': data})}\n\n"
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

    items_result = await db.execute(select(Item).where(Item.college_id == college_id).order_by(Item.item_number))
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


@router.get("/colleges/{college_id}/cards", response_model=CardsListResponseWrapped)
async def list_college_cards(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CardsListResponseWrapped:
    """Toutes les flashcards d'un collège (story 8.3).

    L'app les synchronise en local d'un seul appel : la session du jour mêle les
    collèges et doit fonctionner hors-ligne, sans attendre l'ouverture de chaque item.
    Triées item, rang puis card_type pour un ordre stable.
    """
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

    cards_result = await db.execute(
        select(FlashCard)
        .where(FlashCard.college_id == college_id)
        .order_by(FlashCard.item_id, FlashCard.rang, FlashCard.card_type)
    )
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
            user_feedback=c.user_feedback,
        )
        for c in cards_result.scalars().all()
    ]
    return CardsListResponseWrapped(data=data, total=len(data))


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
        select(FlashCard).where(FlashCard.item_id == item_id).order_by(FlashCard.rang, FlashCard.card_type)
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
            user_feedback=c.user_feedback,
        )
        for c in cards
    ]
    return CardsListResponseWrapped(data=data, total=len(data))
