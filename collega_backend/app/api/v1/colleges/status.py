"""Routes collèges utilisateur — statut d'import et flux SSE de progression (FR9)."""

from __future__ import annotations

import asyncio
import json
import uuid

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import async_session_factory, get_db
from app.core.errors import not_found
from app.deps import get_current_user, get_current_user_short_session
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.schemas.college import (
    CollegeStatusData,
    CollegeStatusResponseWrapped,
)

router = APIRouter()


_SSE_MAX_DURATION = 3 * 3600  # 3h
_SSE_POLL_INTERVAL = 1.5  # s entre deux lectures DB
# Cloudflare / reverse proxies coupent une connexion silencieuse après ~100 s :
# on émet un commentaire SSE `: keep-alive` si aucun événement n'est parti depuis ce délai.
_SSE_HEARTBEAT_INTERVAL = 15.0


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
        raise not_found("COLLEGE_NOT_FOUND", f"College {college_id} not found")

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
        raise not_found("COLLEGE_NOT_FOUND", f"College {college_id} not found")

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
