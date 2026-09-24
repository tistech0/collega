#!/usr/bin/env python3
"""Backfill des titres d'items depuis les PDF déjà importés (Story 8.0).

Les titres sont ré-extraits du PDF source, présent sur le volume `pdf_storage_path`
(les imports antérieurs au chantier 1 n'ont plus de texte OCR en base). Relit le texte (pdfplumber, sans OCR ni appel Claude), extrait les titres avec
`ItemDetector`, alimente le référentiel `item_titles` et complète les items sans titre.
Ne modifie ni pages, ni rangs, ni fiches.

Dans le conteneur worker (volume PDF monté) :
  docker exec collega-worker-1 python -m scripts.backfill_item_titles --dry-run
  docker exec collega-worker-1 python -m scripts.backfill_item_titles
  # Combler un trou que l'extraction ne peut pas lire (source `official`, prioritaire) :
  docker exec collega-worker-1 python -m scripts.backfill_item_titles --set 338="Œdème de Quincke et anaphylaxie"
"""

from __future__ import annotations

import argparse
import asyncio
import uuid
from pathlib import Path

from sqlalchemy import select

from app.core.config import settings
from app.core.database import async_session_factory
from app.models.college import College
from app.models.item import Item
from app.services.ocr.item_detector import ItemDetector
from app.services.ocr.item_titles import ensure_title, record_official_title

ItemRow = tuple[uuid.UUID, int, str | None]


def plan_updates(items: list[ItemRow], extracted: dict[int, str]) -> list[tuple[uuid.UUID, str]]:
    """Items sans titre pour lesquels le PDF fournit un titre : (id, titre)."""
    return [(item_id, extracted[number]) for item_id, number, title in items if not title and number in extracted]


def parse_overrides(values: list[str]) -> dict[int, str]:
    """`--set 338="Titre"` → {338: "Titre"}."""
    overrides: dict[int, str] = {}
    for value in values:
        number, sep, title = value.partition("=")
        if not sep or not number.strip().isdigit() or not title.strip():
            raise ValueError(f"--set attend NUMERO=TITRE, reçu : {value!r}")
        overrides[int(number)] = title.strip()
    return overrides


def extract_titles(pdf_path: Path) -> dict[int, str]:
    import pdfplumber

    with pdfplumber.open(pdf_path) as pdf:
        texts = [page.extract_text() or "" for page in pdf.pages]
    detected = ItemDetector().detect_items(texts).items
    return {d.item_number: d.chapter_title for d in detected if d.chapter_title}


def find_pdf(college_id: uuid.UUID) -> Path | None:
    matches = sorted(Path(settings.pdf_storage_path).glob(f"{college_id}_*.pdf"))
    return matches[-1] if matches else None


async def run(dry_run: bool, overrides: dict[int, str]) -> None:
    async with async_session_factory() as db:
        for number, title in sorted(overrides.items()):
            print(f"libellé officiel {number} · {title}")
            if not dry_run:
                await record_official_title(db, number, title)
        colleges = (await db.execute(select(College))).scalars().all()
        for college in colleges:
            rows = (
                await db.execute(
                    select(Item.id, Item.item_number, Item.chapter_title)
                    .where(Item.college_id == college.id)
                    .order_by(Item.item_number)
                )
            ).all()
            pdf = find_pdf(college.id)
            label = f"collège ref {college.college_ref_id} ({college.id})"
            if pdf is None:
                print(f"{label} : PDF absent du volume, ignoré")
                continue

            extracted = await asyncio.to_thread(extract_titles, pdf)
            item_numbers = {number for _, number, _ in rows}
            for number, title in sorted(extracted.items()):
                if number in item_numbers and not dry_run:
                    await ensure_title(db, number, title)
            updates = plan_updates([tuple(r) for r in rows], extracted)
            if not dry_run:
                # ensure_title complète déjà les items vides ; ceci couvre le cas où le
                # référentiel préfère un autre libellé que celui de ce PDF (déjà titré ailleurs).
                for item_id, title in updates:
                    item = await db.get(Item, item_id)
                    if item is not None and not item.chapter_title:
                        item.chapter_title = title

            missing = sorted(number for _, number, title in rows if not title and number not in extracted)
            print(
                f"{label} : {len(rows)} items, {len(extracted)} titres extraits du PDF, "
                f"{len(updates)} items à compléter, sans titre : {missing or 'aucun'}"
            )
            for number in sorted(item_numbers):
                if number in extracted:
                    print(f"  {number} · {extracted[number]}")

        if dry_run:
            await db.rollback()
            print("--dry-run : aucune écriture")
        else:
            await db.commit()
            print("Titres enregistrés")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--set", action="append", default=[], metavar="NUMERO=TITRE")
    args = parser.parse_args()
    asyncio.run(run(args.dry_run, parse_overrides(args.set)))


if __name__ == "__main__":
    main()
