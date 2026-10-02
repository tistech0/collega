"""Routes collèges utilisateur — le PDF importé, relu dans l'app (partie B).

Réservé au propriétaire ; `FileResponse` gère `Range` (206) pour reprendre un
téléchargement interrompu. Le fichier n'est plus gardé après la génération :
le téléchargement ne sert qu'aux PDF importés avant ce changement (purgés la nuit)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.errors import not_found
from app.deps import get_current_user
from app.models.college import College
from app.models.user import User
from app.schemas.college import PdfFingerprintData, PdfFingerprintResponseWrapped
from app.services import imports as import_service

router = APIRouter()


@router.get("/colleges/{college_id}/pdf", response_class=FileResponse)
async def download_college_pdf(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> FileResponse:
    """Le PDF en service du collège (dernier import publié)."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise not_found("COLLEGE_NOT_FOUND", "College not found")
    pdf = (await import_service.current_pdfs(db, [college.id])).get(college.id)
    if pdf is None or pdf.size is None:
        raise not_found("PDF_NOT_FOUND", "PDF not found")
    return FileResponse(pdf.path, media_type="application/pdf")


@router.get("/colleges/{college_id}/pdf/fingerprint", response_model=PdfFingerprintResponseWrapped)
async def college_pdf_fingerprint(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PdfFingerprintResponseWrapped:
    """Empreinte du PDF en service : l'app vérifie qu'un fichier choisi sur le
    téléphone est bien celui importé (mêmes numéros de page) avant de le rattacher."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise not_found("COLLEGE_NOT_FOUND", "College not found")
    pdf = (await import_service.current_pdfs(db, [college.id])).get(college.id)
    if pdf is None:
        raise not_found("PDF_NOT_FOUND", "PDF not found")
    return PdfFingerprintResponseWrapped(data=PdfFingerprintData(pdf_version=str(pdf.job_id), pdf_sha256=pdf.sha256))
