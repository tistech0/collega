"""Routes admin Phase 0 — pipeline OCR.

Ces routes seront étendues en Story 1.4 (monitoring queue, gestion beta, stats).
Pour l'instant : soumission PDF et consultation du statut OCR uniquement.
Toutes les routes sont protégées par HTTP Basic Auth.
"""
from __future__ import annotations

import logging
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.deps import get_admin_user
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.schemas.admin import (
    CollegeStatusData,
    CollegeStatusResponseWrapped,
    ProcessCollegeResponse,
    ProcessCollegeResponseWrapped,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["admin"])

_PDF_MAGIC = b"%PDF-"
_CHUNK_SIZE = 1024 * 1024  # 1 MB — évite de charger l'intégralité du fichier en mémoire


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
