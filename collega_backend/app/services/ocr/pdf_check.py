"""Refus immédiat d'un PDF endommagé (chantier 1).

Les magic bytes `%PDF-` ne suffisent pas : un fichier corrompu (ex. index de fin
qui pointe au milieu des données) passe ce contrôle puis échoue à l'OCR avec
« 0 page ». On l'ouvre à la réception, avant toute consommation de quota ou
création d'import.
"""
import asyncio
import logging
from pathlib import Path

from fastapi import HTTPException

from app.services.ocr.ocr_processor import OcrProcessor

logger = logging.getLogger(__name__)

PDF_DAMAGED_MESSAGE = "Ce PDF est endommagé : il ne s'ouvre pas. Réessaie avec une autre copie."


def pdf_damaged() -> HTTPException:
    return HTTPException(status_code=422, detail={"code": "PDF_DAMAGED", "message": PDF_DAMAGED_MESSAGE})


async def assert_pdf_readable(path: Path) -> int:
    """Nombre de pages ; 422 PDF_DAMAGED si le fichier ne s'ouvre pas ou n'a aucune page."""
    try:
        pages = await asyncio.to_thread(OcrProcessor().count_pages, path)
    except Exception as exc:  # noqa: BLE001 — toute erreur d'ouverture = PDF endommagé
        logger.info("PDF endommagé refusé (%s) : %r", path.name, exc)
        raise pdf_damaged()
    if pages <= 0:
        raise pdf_damaged()
    return pages
