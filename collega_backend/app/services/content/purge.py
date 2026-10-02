"""Purges du contenu et des PDF (chantier 1).

- Contenu partagé (pages OCR, textes d'items, générations) : supprimé quand plus
  aucun collège ni import en cours ne le référence. Ce qui sert encore à une
  autre utilisatrice (même PDF) est conservé : c'est aussi son contenu.
- PDF : on ne garde que celui de chaque import actif (le temps de l'OCR et de la
  génération) ; le reste est orphelin. La copie relue dans l'app est celle du
  téléphone : le serveur ne conserve pas les œuvres (droits des éditeurs).
- Exception : les générations « texte insuffisant » (0 fiche, minuscules) et leurs
  textes d'items ne sont jamais purgées — un item modifié devenu insuffisant garde
  son ancien contenu, sa nouvelle génération n'est référencée par rien, et la purger
  ferait repayer Claude à chaque réimport (chantier 4). Le vidage (wipe_content) les
  supprime.
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.generation_job import GenerationJob
from app.services.content.store import hold_content_lock_exclusive
from app.services.imports import file_sha256, pdf_path_for

logger = logging.getLogger(__name__)

_PURGE_STATEMENTS = {
    "item_generations": """
        DELETE FROM item_generations g
        WHERE NOT g.insufficient_text
          AND NOT EXISTS (SELECT 1 FROM flash_cards f WHERE f.generation_id = g.id)
          AND NOT EXISTS (SELECT 1 FROM job_items j WHERE j.generation_id = g.id)
          AND NOT EXISTS (SELECT 1 FROM items i WHERE i.text_hash = g.text_hash)
          AND NOT EXISTS (SELECT 1 FROM job_items j2 WHERE j2.text_hash = g.text_hash)
    """,
    "item_texts": """
        DELETE FROM item_texts t
        WHERE NOT EXISTS (SELECT 1 FROM items i WHERE i.text_hash = t.hash)
          AND NOT EXISTS (SELECT 1 FROM job_items j WHERE j.text_hash = t.hash)
          AND NOT EXISTS (SELECT 1 FROM item_generations g WHERE g.text_hash = t.hash)
    """,
    "ocr_pages": """
        DELETE FROM ocr_pages p
        WHERE NOT EXISTS (SELECT 1 FROM job_pages j WHERE j.page_hash = p.hash)
          AND NOT EXISTS (SELECT 1 FROM college_pages c WHERE c.page_hash = p.hash)
    """,
}

# Un PDF récent peut être en cours d'écriture (import pas encore en base) : jamais
# supprimé avant ce délai, quel que soit son nom.
PDF_GRACE = timedelta(hours=24)
ACTIVE_STATUSES = ("pending", "processing", "ocr_complete")


async def purge_unreferenced_content(db: AsyncSession) -> dict[str, int]:
    """Supprime le contenu que plus rien ne référence. Ne commit pas."""
    await hold_content_lock_exclusive(db)
    counts = {}
    for table, statement in _PURGE_STATEMENTS.items():  # ordre : générations → textes → pages
        result = await db.execute(text(statement))
        counts[table] = getattr(result, "rowcount", 0) or 0
    if any(counts.values()):
        logger.info("Contenu non référencé purgé : %s", counts)
    return counts


def delete_college_pdfs(college_id: uuid.UUID) -> int:
    removed = 0
    for pdf in Path(settings.pdf_storage_path).glob(f"{college_id}_*.pdf"):
        try:
            pdf.unlink(missing_ok=True)
            removed += 1
        except OSError:
            logger.warning("PDF non supprimé : %s", pdf, exc_info=True)
    return removed


async def active_pdf_names(db: AsyncSession) -> set[str]:
    """PDF à conserver : ceux des imports actifs."""
    rows = (
        await db.execute(
            select(GenerationJob.college_id, GenerationJob.id).where(GenerationJob.status.in_(ACTIVE_STATUSES))
        )
    ).all()
    return {f"{college_id}_{job_id}.pdf" for college_id, job_id in rows}


async def backfill_pdf_hashes(db: AsyncSession) -> int:
    """Empreinte des imports publiés qui n'en ont pas, tant que leur PDF est encore
    là (imports d'avant le calcul à l'OCR) : sans elle, l'app ne pourrait pas
    vérifier le fichier rattaché. À appeler avant la purge des PDF. Ne commit pas."""
    jobs = (
        (
            await db.execute(
                select(GenerationJob).where(
                    GenerationJob.status == "generation_complete", GenerationJob.pdf_hash.is_(None)
                )
            )
        )
        .scalars()
        .all()
    )
    filled = 0
    for job in jobs:
        path = pdf_path_for(job.college_id, job.id)
        if not path.exists():
            continue
        try:
            job.pdf_hash = await asyncio.to_thread(file_sha256, path)
            filled += 1
        except OSError:
            logger.warning("Empreinte du PDF %s non calculée", path, exc_info=True)
    return filled


def purge_orphan_pdfs(keep: set[str], now: datetime | None = None) -> int:
    """Supprime les PDF hors de `keep` (dont les assemblages `incoming_*`) modifiés
    depuis plus de 24 h."""
    now = now or datetime.now(UTC)
    removed = 0
    for pdf in Path(settings.pdf_storage_path).glob("*.pdf"):
        if pdf.name in keep:
            continue
        if now - datetime.fromtimestamp(pdf.stat().st_mtime, UTC) <= PDF_GRACE:
            continue
        try:
            pdf.unlink(missing_ok=True)
            removed += 1
        except OSError:
            logger.warning("PDF orphelin non supprimé : %s", pdf, exc_info=True)
    if removed:
        logger.info("%d PDF orphelins supprimés", removed)
    return removed
