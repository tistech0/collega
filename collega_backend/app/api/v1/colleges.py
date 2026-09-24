"""Routes collèges utilisateur — FR7 (liste), FR8-FR9 (import PDF + SSE)."""

from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import UTC, datetime
from pathlib import Path

from arq.connections import ArqRedis
from fastapi import APIRouter, Depends, HTTPException, Request, Response, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import async_session_factory, get_db
from app.core.time_utils import next_month_reset as _next_month_reset
from app.deps import get_arq, get_current_user, get_current_user_short_session, require_subscription
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
from app.services import app_settings, imports
from app.services.ocr.pdf_check import assert_pdf_readable
from app.services.upload.chunked_upload import (
    MAX_UPLOAD_SIZE,
    ChunkedUploadStore,
    InvalidPartIndex,
    PartSizeError,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["colleges"])


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
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)

    return ReloadLimitsResponseWrapped(
        data=ReloadLimitsData(
            college_reload_count=college.reload_count,
            college_reload_max=reload_count_max,
            monthly_reloads=effective_monthly,
            monthly_max=monthly_reloads_max,
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
    arq: ArqRedis = Depends(get_arq),
) -> ImportCollegeResponseWrapped:
    """Soumet un PDF pour traitement OCR — crée le College si nécessaire (mono-requête, ≤ 100 MB
    derrière Cloudflare ; au-delà, voir /import/init)."""
    imports.validate_ref_id(ref_id)
    college = await imports.get_or_create_college(db, current_user, ref_id)
    await imports.assert_no_active_job(db, college)
    await imports.apply_reimport_quota(db, current_user, college, await app_settings.anti_spam_limits(db))

    job_id = uuid.uuid4()
    pdf_file_path = imports.pdf_path_for(college.id, job_id)
    await imports.save_upload(pdf, pdf_file_path, max_size=imports.MAX_PDF_SIZE)

    try:
        await assert_pdf_readable(pdf_file_path)
    except HTTPException:
        # Quota (UPDATE non validé) annulé : un PDF endommagé ne coûte rien.
        pdf_file_path.unlink(missing_ok=True)
        await db.rollback()
        raise

    logger.info("PDF saved for college %s (ref_id=%s) at %s", college.id, ref_id, pdf_file_path)

    await imports.create_job_and_enqueue(
        db, arq, college=college, user_id=current_user.id, job_id=job_id, pdf_path=pdf_file_path
    )
    return ImportCollegeResponseWrapped(data=imports.import_response(college, job_id))


# ── Story 7.11 — upload par morceaux (Cloudflare : 100 MB max par requête) ──────


async def get_upload_store(arq: ArqRedis = Depends(get_arq)) -> ChunkedUploadStore:
    """Store d'upload : Redis via le pool ARQ unique (redis.asyncio) + volume pdf_storage."""
    return ChunkedUploadStore(arq, Path(settings.pdf_storage_path))


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
    await imports.assert_import_allowed(db, current_user, ref_id, await app_settings.anti_spam_limits(db))
    if body.size_bytes > MAX_UPLOAD_SIZE:
        raise imports.file_too_large()
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
    arq: ArqRedis = Depends(get_arq),
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
        if not f.read(len(imports.PDF_MAGIC)).startswith(imports.PDF_MAGIC):
            await store.claim(state.upload_id)
            store.purge(state.upload_id)
            raise imports.invalid_pdf_signature()

    # Prise de possession atomique : un complete concurrent qui perd le DEL reçoit 409.
    claimed = await store.claim(state.upload_id)
    if claimed is None:
        raise imports.job_in_progress()

    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)
    assembled = storage_path / f"incoming_{state.upload_id}.pdf"
    try:
        store.assemble(claimed, assembled)
        await assert_pdf_readable(assembled)
        limits = await app_settings.anti_spam_limits(db)
        data = await imports.start_import_from_file(db, arq, current_user, claimed.ref_id, assembled, limits)
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
