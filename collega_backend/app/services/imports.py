"""Service d'import partagé (chantier 5, § 2) — import utilisatrice (`/v1/colleges`) et import admin.

Création/réutilisation du collège, contrôle du PDF reçu, verrou « un job actif par collège »,
quota de réimport, création du GenerationJob et mise en file ARQ : écrits une seule fois ici.
Les routes ne gardent que la lecture de la requête et la réponse HTTP.
"""

from __future__ import annotations

import logging
import os
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from arq.connections import ArqRedis
from fastapi import UploadFile
from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import AppError, conflict, unprocessable
from app.core.time_utils import next_month_reset
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.schemas.college import ImportCollegeResponseData

logger = logging.getLogger(__name__)

PDF_MAGIC = b"%PDF-"
MAX_PDF_SIZE = 500 * 1024 * 1024  # 500 MB
# Aligné sur l'index UNIQUE partiel de la migration 012 (ocr_complete = génération Claude en cours).
ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")
_CHUNK_SIZE = 1024 * 1024  # 1 MB — le PDF n'est jamais chargé entier en mémoire


# ── Erreurs ──────────────────────────────────────────────────────────────────


def job_in_progress() -> AppError:
    return conflict("JOB_IN_PROGRESS", "Un import est déjà en cours pour ce collège")


def _invalid_file_type(message: str) -> AppError:
    return unprocessable("INVALID_FILE_TYPE", message)


def invalid_pdf_signature() -> AppError:
    return _invalid_file_type("Le fichier ne semble pas être un PDF valide")


def file_too_large() -> AppError:
    return AppError(413, "FILE_TOO_LARGE", "Le PDF ne doit pas dépasser 500 MB")


def _college_reload_limit(college: College, reload_count_max: int) -> AppError:
    return conflict(
        "COLLEGE_RELOAD_LIMIT",
        f"Ce collège ne peut plus être retraité (limite : {reload_count_max})",
        reload_count=college.reload_count,
        reload_count_max=reload_count_max,
    )


def _monthly_reload_limit(user: User, now: datetime, monthly_reloads_max: int) -> AppError:
    reset_at = user.monthly_reloads_reset_at or next_month_reset(now)
    return conflict(
        "MONTHLY_RELOAD_LIMIT",
        f"Limite mensuelle atteinte ({monthly_reloads_max} reimports/mois)",
        monthly_reloads=user.monthly_reloads,
        monthly_max=monthly_reloads_max,
        reset_at=reset_at.isoformat(),
    )


# ── Collège, verrou, quota ───────────────────────────────────────────────────


def validate_ref_id(ref_id: int) -> None:
    if not (1 <= ref_id <= 39):
        raise unprocessable("INVALID_REF_ID", "ref_id must be between 1 and 39")


async def _select_college(db: AsyncSession, user: User, ref_id: int) -> College | None:
    result = await db.execute(select(College).where(College.user_id == user.id).where(College.college_ref_id == ref_id))
    return result.scalar_one_or_none()


async def get_or_create_college(db: AsyncSession, user: User, ref_id: int) -> College:
    """Collège (utilisatrice, ref_id) existant ou créé (flush). Une création concurrente → 409."""
    college = await _select_college(db, user, ref_id)
    if college is None:
        college = College(user_id=user.id, college_ref_id=ref_id)
        db.add(college)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raise job_in_progress() from None
    return college


async def assert_no_active_job(db: AsyncSession, college: College) -> None:
    """409 JOB_IN_PROGRESS si un job actif existe (inclut ocr_complete : génération en cours)."""
    existing_job = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college.id)
        .where(GenerationJob.status.in_(ACTIVE_JOB_STATUSES))
    )
    if existing_job.scalar_one_or_none() is not None:
        raise job_in_progress()


async def apply_reimport_quota(db: AsyncSession, user: User, college: College, limits: tuple[int, int]) -> None:
    """Quota checks pour les reimports uniquement (premier import = libre).
    Atomique : UPDATE conditionnel avec RETURNING — pas de race read-then-check.
    `limits` = (reload_count_max, monthly_reloads_max), lus une fois par requête."""
    if college.status != "generation_complete":
        return

    reload_count_max, monthly_reloads_max = limits
    now = datetime.now(UTC)
    is_month_reset = user.monthly_reloads_reset_at is None or now >= user.monthly_reloads_reset_at

    # 1. Reset mensuel lazy (filet de sécurité — cron quotidien est la source défensive)
    if is_month_reset:
        user.monthly_reloads = 0
        user.monthly_reloads_reset_at = next_month_reset(now)
        await db.flush()

    # 2. Incrément atomique College.reload_count
    college_update = await db.execute(
        sa_update(College)
        .where(College.id == college.id)
        .where(College.reload_count < reload_count_max)
        .values(reload_count=College.reload_count + 1)
        .returning(College.reload_count)
    )
    if college_update.scalar_one_or_none() is None:
        raise _college_reload_limit(college, reload_count_max)

    # 3. Incrément atomique User.monthly_reloads — rollback college si échec
    user_update = await db.execute(
        sa_update(User)
        .where(User.id == user.id)
        .where(User.monthly_reloads < monthly_reloads_max)
        .values(monthly_reloads=User.monthly_reloads + 1)
        .returning(User.monthly_reloads)
    )
    if user_update.scalar_one_or_none() is None:
        # L'erreur DOIT être construite avant le rollback : `db.rollback()` expire les
        # objets ORM de la session (dont `user`), et lire ses attributs après coup
        # déclencherait un lazy-load synchrone → MissingGreenlet (I2).
        error = _monthly_reload_limit(user, now, monthly_reloads_max)
        # Annule l'incrément college fait juste avant (transaction non commitée)
        await db.rollback()
        raise error


async def assert_import_allowed(db: AsyncSession, user: User, ref_id: int, limits: tuple[int, int]) -> College | None:
    """Gardes d'import en lecture seule (aucune écriture) — utilisées par POST /import/init
    (morceaux) avant de recevoir le moindre octet. Renvoie le College existant ou None.
    Lève les mêmes AppError que le chemin d'import (422 INVALID_REF_ID, 409 JOB_IN_PROGRESS,
    409 COLLEGE_RELOAD_LIMIT / MONTHLY_RELOAD_LIMIT) ; le quota réel est consommé à `complete`."""
    validate_ref_id(ref_id)
    college = await _select_college(db, user, ref_id)
    if college is None:
        return None
    await assert_no_active_job(db, college)

    if college.status == "generation_complete":
        now = datetime.now(UTC)
        month_reset_due = user.monthly_reloads_reset_at is None or now >= user.monthly_reloads_reset_at
        reload_count_max, monthly_reloads_max = limits
        if college.reload_count >= reload_count_max:
            raise _college_reload_limit(college, reload_count_max)
        if not month_reset_due and user.monthly_reloads >= monthly_reloads_max:
            raise _monthly_reload_limit(user, now, monthly_reloads_max)
    return college


# ── PDF ──────────────────────────────────────────────────────────────────────


def pdf_path_for(college_id: uuid.UUID, job_id: uuid.UUID) -> Path:
    """`{college_id}_{job_id}.pdf` dans le volume partagé (convention attendue par la purge admin)."""
    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)
    return storage_path / f"{college_id}_{job_id}.pdf"


@dataclass(frozen=True)
class CurrentPdf:
    """PDF en service d'un collège (partie B) : celui du dernier import publié."""

    job_id: uuid.UUID
    path: Path
    size: int


async def current_pdfs(db: AsyncSession, college_ids: Sequence[uuid.UUID]) -> dict[uuid.UUID, CurrentPdf]:
    """Dernier job `generation_complete` de chaque collège dont le fichier existe encore.

    Pendant un réimport, le nouveau PDF est déjà sur le disque mais son job n'est pas publié :
    c'est l'ancien qui reste en service (ses numéros de page sont ceux des items en base)."""
    if not college_ids:
        return {}
    rows = (
        await db.execute(
            select(GenerationJob.college_id, GenerationJob.id)
            .where(
                GenerationJob.college_id.in_(list(college_ids)),
                GenerationJob.status == "generation_complete",
            )
            .order_by(GenerationJob.college_id, GenerationJob.created_at.desc())
            .distinct(GenerationJob.college_id)
        )
    ).all()
    found: dict[uuid.UUID, CurrentPdf] = {}
    for college_id, job_id in rows:
        path = pdf_path_for(college_id, job_id)
        try:
            size = path.stat().st_size
        except OSError:
            continue
        found[college_id] = CurrentPdf(job_id=job_id, path=path, size=size)
    return found


async def save_upload(upload: UploadFile, dest: Path, *, max_size: int | None) -> None:
    """Écrit le PDF reçu dans `dest` par blocs de 1 MB.

    422 INVALID_FILE_TYPE si ni le content-type ni l'extension ne désignent un PDF, ou si la
    signature `%PDF-` manque ; 413 FILE_TOO_LARGE au-delà de `max_size` (None = pas de limite).
    Le fichier partiel est supprimé sur toute erreur."""
    is_pdf = (upload.content_type == "application/pdf") or (upload.filename or "").lower().endswith(".pdf")
    if not is_pdf:
        raise _invalid_file_type("Le fichier doit être un PDF")

    first_chunk = await upload.read(_CHUNK_SIZE)
    if not first_chunk.startswith(PDF_MAGIC):
        raise invalid_pdf_signature()

    total_size = len(first_chunk)
    try:
        with open(dest, "wb") as f:
            f.write(first_chunk)
            while chunk := await upload.read(_CHUNK_SIZE):
                total_size += len(chunk)
                if max_size is not None and total_size > max_size:
                    raise file_too_large()
                f.write(chunk)
    except BaseException:
        dest.unlink(missing_ok=True)
        raise


# ── Job ──────────────────────────────────────────────────────────────────────


async def create_job_and_enqueue(
    db: AsyncSession,
    arq: ArqRedis,
    *,
    college: College,
    user_id: uuid.UUID,
    job_id: uuid.UUID,
    pdf_path: Path,
) -> GenerationJob:
    """Crée le GenerationJob (pending) et met l'OCR en file. Supprime le PDF sur toute erreur.

    409 JOB_IN_PROGRESS : course détectée par l'index UNIQUE partiel sur (college_id) WHERE statut
    actif (migration 012). 503 QUEUE_UNAVAILABLE : enqueue impossible, le job est supprimé."""
    job = GenerationJob(id=job_id, college_id=college.id, user_id=user_id, status="pending")
    db.add(job)
    try:
        await db.commit()
        await db.refresh(job)
    except IntegrityError:
        await db.rollback()
        pdf_path.unlink(missing_ok=True)
        raise job_in_progress() from None
    except Exception:
        pdf_path.unlink(missing_ok=True)
        raise

    try:
        arq_job = await arq.enqueue_job("process_college_ocr", str(college.id), str(job_id), str(pdf_path))
        if arq_job is not None:
            job.arq_job_id = arq_job.job_id
            await db.commit()
        logger.info("OCR job %s enqueued for college %s", job_id, college.id)
    except Exception as exc:  # noqa: BLE001
        logger.error("Failed to enqueue OCR job: %s", exc)
        await db.delete(job)
        await db.commit()
        pdf_path.unlink(missing_ok=True)
        raise AppError(503, "QUEUE_UNAVAILABLE", "Impossible d'enqueuer le job OCR — réessayez") from exc
    return job


async def start_import_from_file(
    db: AsyncSession, arq: ArqRedis, user: User, ref_id: int, pdf_path: Path, limits: tuple[int, int]
) -> ImportCollegeResponseData:
    """Import à partir d'un PDF déjà écrit sur le volume partagé (upload par morceaux assemblé) :
    get/create College, garde job actif, quotas atomiques, renommage en `{college.id}_{job_id}.pdf`
    (convention attendue par la purge admin), GenerationJob + enqueue. Supprime le PDF sur toute erreur."""
    try:
        college = await get_or_create_college(db, user, ref_id)
        await assert_no_active_job(db, college)
        await apply_reimport_quota(db, user, college, limits)
    except AppError:
        pdf_path.unlink(missing_ok=True)
        raise

    job_id = uuid.uuid4()
    final_path = pdf_path.with_name(f"{college.id}_{job_id}.pdf")
    os.replace(pdf_path, final_path)
    logger.info("PDF ready for college %s (ref_id=%s) at %s", college.id, ref_id, final_path)
    await create_job_and_enqueue(db, arq, college=college, user_id=user.id, job_id=job_id, pdf_path=final_path)
    return import_response(college, job_id)


def import_response(college: College, job_id: uuid.UUID) -> ImportCollegeResponseData:
    return ImportCollegeResponseData(college_id=str(college.id), job_id=str(job_id), status="pending")
