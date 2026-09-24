"""Routes admin — imports en cours : file, détail, arrêt.

Toutes les routes sont protégées par HTTP Basic Auth.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from arq.connections import ArqRedis
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import async_session_factory, get_db
from app.core.errors import conflict, not_found
from app.deps import get_admin_user, get_arq_optional
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.models.item import Item
from app.schemas.admin import (
    ItemOcrData,
    JobDetailData,
    JobDetailResponseWrapped,
    JobEventData,
    QueueJobData,
    QueueResponse,
    StopJobData,
    StopJobResponseWrapped,
)
from app.services import imports
from app.services.generation.token_cost import compute_cost_eur
from app.services.jobs.arq_control import abort_arq_job
from app.services.jobs.job_failure import fail_job
from app.services.ocr.item_detector import segmentation_overview

router = APIRouter()


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


# ── Story 7.7 — Suivi & contrôle des imports (timeline / détail / stop / delete) ─


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
        raise not_found("JOB_NOT_FOUND", f"Job {job_id} not found")

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
            segmentation=segmentation_overview(job.segmentation_report),
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
    arq: ArqRedis | None = Depends(get_arq_optional),
) -> StopJobResponseWrapped:
    """Annule un job ARQ actif et force son statut DB à 'failed'.

    L'abort ARQ est best-effort (le worker ne catche pas CancelledError) : c'est
    l'endpoint qui est seul garant du statut DB. Réutiliser `failed` (et non un
    `cancelled`) évite d'altérer la CheckConstraint et libère l'index UNIQUE
    partiel (migration 012) → un réimport redevient possible. Décision PL 2026-06-17.
    """
    job = await db.get(GenerationJob, job_id)
    if job is None:
        raise not_found("JOB_NOT_FOUND", f"Job {job_id} not found")
    if job.status not in imports.ACTIVE_JOB_STATUSES:
        raise conflict("JOB_NOT_ACTIVE", "Job is not active — nothing to cancel")

    # Abort ARQ best-effort. L'arq_job_id pointe toujours sur le job ARQ actif
    # (OCR puis génération, cf. fix persistance dans ocr_worker). On REMONTE le
    # résultat (review 7.7 D2) : sans cela l'admin croit avoir stoppé alors que
    # l'abort a pu échouer silencieusement (Redis down, flag worker absent) et que
    # le worker tourne encore. Le statut DB est forcé indépendamment du résultat.
    aborted = False
    if job.arq_job_id:
        # Redis injoignable (arq None) : abort impossible, le statut DB est forcé quand même.
        aborted = await abort_arq_job(arq, job.arq_job_id)

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
