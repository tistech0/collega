"""Routes collèges utilisateur — import PDF (FR8) : upload simple et par morceaux (story 7.11)."""

from __future__ import annotations

import logging
import uuid
from pathlib import Path

from arq.connections import ArqRedis
from fastapi import APIRouter, Depends, Request, Response, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.errors import AppError, conflict, not_found, unprocessable
from app.deps import get_arq, require_subscription
from app.models.user import User
from app.schemas.college import (
    ImportCollegeResponseWrapped,
    UploadInitData,
    UploadInitRequest,
    UploadInitResponseWrapped,
    UploadStatusData,
    UploadStatusResponseWrapped,
)
from app.services import app_settings
from app.services import imports as import_service
from app.services.ocr.pdf_check import assert_pdf_readable
from app.services.upload.chunked_upload import (
    MAX_UPLOAD_SIZE,
    ChunkedUploadStore,
    InvalidPartIndex,
    PartSizeError,
)

logger = logging.getLogger(__name__)
router = APIRouter()


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
    import_service.validate_ref_id(ref_id)
    college = await import_service.get_or_create_college(db, current_user, ref_id)
    await import_service.assert_no_active_job(db, college)
    await import_service.apply_reimport_quota(db, current_user, college, await app_settings.anti_spam_limits(db))

    job_id = uuid.uuid4()
    pdf_file_path = import_service.pdf_path_for(college.id, job_id)
    await import_service.save_upload(pdf, pdf_file_path, max_size=import_service.MAX_PDF_SIZE)

    try:
        await assert_pdf_readable(pdf_file_path)
    except AppError:
        # Quota (UPDATE non validé) annulé : un PDF endommagé ne coûte rien.
        pdf_file_path.unlink(missing_ok=True)
        await db.rollback()
        raise

    logger.info("PDF saved for college %s (ref_id=%s) at %s", college.id, ref_id, pdf_file_path)

    await import_service.create_job_and_enqueue(
        db, arq, college=college, user_id=current_user.id, job_id=job_id, pdf_path=pdf_file_path
    )
    return ImportCollegeResponseWrapped(data=import_service.import_response(college, job_id))


# ── Story 7.11 — upload par morceaux (Cloudflare : 100 MB max par requête) ──────


async def get_upload_store(arq: ArqRedis = Depends(get_arq)) -> ChunkedUploadStore:
    """Store d'upload : Redis via le pool ARQ unique (redis.asyncio) + volume pdf_storage."""
    return ChunkedUploadStore(arq, Path(settings.pdf_storage_path))


def _upload_not_found() -> AppError:
    return not_found("UPLOAD_NOT_FOUND", "Upload inconnu ou expiré — relancer l'import")


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
    await import_service.assert_import_allowed(db, current_user, ref_id, await app_settings.anti_spam_limits(db))
    if body.size_bytes > MAX_UPLOAD_SIZE:
        raise import_service.file_too_large()
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
        raise unprocessable("INVALID_PART", f"Morceau invalide : {exc}") from exc
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
        raise conflict("UPLOAD_INCOMPLETE", "Morceaux manquants", missing=state.missing)
    with open(store.part_path(state.upload_id, 0), "rb") as f:
        if not f.read(len(import_service.PDF_MAGIC)).startswith(import_service.PDF_MAGIC):
            await store.claim(state.upload_id)
            store.purge(state.upload_id)
            raise import_service.invalid_pdf_signature()

    # Prise de possession atomique : un complete concurrent qui perd le DEL reçoit 409.
    claimed = await store.claim(state.upload_id)
    if claimed is None:
        raise import_service.job_in_progress()

    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)
    assembled = storage_path / f"incoming_{state.upload_id}.pdf"
    try:
        store.assemble(claimed, assembled)
        await assert_pdf_readable(assembled)
        limits = await app_settings.anti_spam_limits(db)
        data = await import_service.start_import_from_file(db, arq, current_user, claimed.ref_id, assembled, limits)
    except AppError as exc:
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
