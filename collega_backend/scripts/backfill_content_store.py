#!/usr/bin/env python3
"""Remplit le stockage de contenu des collèges importés avant le chantier 1.

Leur texte OCR avait été purgé (ancienne règle des 24 h) : il est relu dans le PDF
en service (pdfplumber, sans appel Claude), puis :
- pages → `ocr_pages` (par empreinte) et `college_pages` ;
- items détectés → `item_texts`, et `items.text_hash` renseigné pour chaque item
  déjà en service portant le même numéro.
Ne crée ni ne supprime aucun item ni aucune fiche, et ne crée aucune génération
(les fiches actuelles ont pu être régénérées ou supprimées : elles ne doivent pas
devenir des « sorties d'origine » partagées). Idempotent.

Effet : le prochain réimport d'un PDF identique retrouve les mêmes empreintes et
garde les fiches (et la progression) au lieu de tout régénérer.

Dans le conteneur worker (volume PDF monté) :
  docker exec collega-worker-1 python -m scripts.backfill_content_store --dry-run
  docker exec collega-worker-1 python -m scripts.backfill_content_store
  docker exec collega-worker-1 python -m scripts.backfill_content_store --college <uuid>
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import uuid
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.college import College, CollegeStatus
from app.models.content import CollegePage
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.services.content import store
from app.services.ocr.item_detector import ItemDetector
from app.services.ocr.ocr_processor import OcrProcessor
from app.workers.ocr_worker import dedupe_items, with_pages

logger = logging.getLogger(__name__)


def current_pdf(college_id: uuid.UUID, job_id: uuid.UUID, pdf_dir: Path) -> Path | None:
    path = pdf_dir / f"{college_id}_{job_id}.pdf"
    return path if path.exists() else None


async def backfill_college(
    db: AsyncSession, college: College, *, processor=None, detector=None, pdf_dir: Path | None = None
) -> dict:
    """Remplit un collège ; ne commit pas. Rapport : pages, items rapprochés / non rapprochés."""
    processor = processor or OcrProcessor()
    detector = detector or ItemDetector()
    pdf_dir = pdf_dir or Path(settings.pdf_storage_path)
    last_job = (
        await db.execute(
            select(GenerationJob)
            .where(GenerationJob.college_id == college.id, GenerationJob.status == "generation_complete")
            .order_by(GenerationJob.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    pdf = current_pdf(college.id, last_job.id, pdf_dir) if last_job else None
    if pdf is None:
        return {"error": "PDF en service introuvable", "pages": 0, "matched": [], "unmatched": []}

    total = await asyncio.to_thread(processor.count_pages, str(pdf))
    texts, scores, tables, hashes = [], [], [], []
    for n in range(total):
        page = await asyncio.to_thread(processor.process_page, str(pdf), n)
        hashes.append(await store.put_page(db, page.text, page.tables, page.confidence_score, page.method))
        texts.append(page.text)
        scores.append(page.confidence_score)
        tables.append(page.tables)
    await db.execute(delete(CollegePage).where(CollegePage.college_id == college.id))
    db.add_all(CollegePage(college_id=college.id, page_number=n, page_hash=h) for n, h in enumerate(hashes))

    live = {i.item_number: i for i in (await db.execute(select(Item).where(Item.college_id == college.id))).scalars()}
    matched, unmatched = [], []
    for detected, pages in with_pages(dedupe_items(detector.detect_items(texts, scores, tables)), texts):
        item = live.get(detected.item_number)
        if item is None:
            unmatched.append(detected.item_number)
            continue
        item.text_hash = await store.put_item_text(db, pages)
        matched.append(detected.item_number)
    await db.flush()
    return {"pages": total, "matched": sorted(matched), "unmatched": sorted(unmatched),
            "without_hash": sorted(n for n, i in live.items() if i.text_hash is None)}


async def run(dry_run: bool, college_id: uuid.UUID | None) -> None:
    from app.core.database import async_session_factory

    async with async_session_factory() as db:
        query = select(College).where(College.status == CollegeStatus.generation_complete)
        if college_id:
            query = query.where(College.id == college_id)
        colleges = (await db.execute(query)).scalars().all()
    for college in colleges:
        async with async_session_factory() as db:
            college = await db.get(College, college.id)
            report = await backfill_college(db, college)
            label = f"collège ref {college.college_ref_id} ({college.id})"
            if "error" in report:
                print(f"{label} : {report['error']}, ignoré")
                continue
            print(
                f"{label} : {report['pages']} pages, {len(report['matched'])} items rapprochés, "
                f"non rapprochés (détectés, absents en service) : {report['unmatched'] or 'aucun'}, "
                f"items en service sans empreinte : {report['without_hash'] or 'aucun'}"
            )
            if dry_run:
                await db.rollback()
            else:
                await db.commit()
    print("--dry-run : aucune écriture" if dry_run else "Stockage de contenu rempli")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--college", type=uuid.UUID, default=None)
    args = parser.parse_args()
    asyncio.run(run(args.dry_run, args.college))


if __name__ == "__main__":
    main()
