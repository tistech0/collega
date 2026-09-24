#!/usr/bin/env python3
"""Vidage complet du contenu (chantier 4, spec § 8), exécuté une fois après le
déploiement du chantier 4, avec l'accord déjà donné par l'utilisateur (C6) : il
est seul utilisateur et réimporte ses collèges de zéro depuis l'app.

Supprime :
- tous les collèges et, en cascade (`ON DELETE CASCADE` en base) : items,
  fiches, imports (`generation_jobs`), leurs événements et brouillons
  (`job_pages`/`job_items`), `college_pages` ;
- le stock de contenu partagé (`ocr_pages`, `item_texts`, `item_generations`),
  y compris les générations `insufficient_text` que la purge courante ne
  touche jamais (cf. `app/services/content/purge.py`) ;
- les PDF restants du volume (`settings.pdf_storage_path` : fichiers `*.pdf`
  et dossier `uploads/`) ;
- les titres non officiels d'`item_titles` (source `official` conservée).

Conserve :
- les comptes (`users`) ;
- les abonnements (`users.is_subscribed` — pas de table séparée) ;
- `claude_usage` : `college_id`/`job_id` passent à NULL par `ON DELETE SET
  NULL` (voir `app/models/claude_usage.py`), la ligne et son coût restent
  dans les totaux admin ;
- `app_settings`.

Remet à zéro `users.monthly_reloads` et `users.monthly_reloads_reset_at` pour
toutes les utilisatrices. `colleges.reload_count` n'a rien à recevoir : les
collèges disparaissent avec le reste.

Redis : rien à vider — le chantier 4 n'y stocke aucun contenu, seulement des
verrous et de l'état d'upload à courte durée de vie (TTL) et le rate limiting.

Un seul commit pour la partie base ; les fichiers ne sont supprimés qu'après
ce commit. Affiche les comptes avant/après (table et nombre seulement, jamais
de texte de page ou de fiche). Refuse de tourner sans `--confirm` (rien n'est
touché, code de sortie 1).

Dans le conteneur api (l'image contient `scripts/`) :
  docker exec collega-api-1 python scripts/wipe_content.py --confirm
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import shutil
import sys
from pathlib import Path

from sqlalchemy import delete, func, select
from sqlalchemy import update as sql_update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings
from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.models.content import CollegePage, ItemGeneration, ItemText, JobItem, JobPage, OcrPage
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.models.item import Item
from app.models.item_title import ItemTitle
from app.models.user import User

logger = logging.getLogger(__name__)

# Tables affichées avant/après (ordre du rapport). colleges → college_pages :
# vidées par la cascade DB au départ des collèges ; ocr_pages → item_generations :
# stock de contenu partagé, vidé explicitement ensuite ; item_titles perd ses
# titres non officiels ; users et claude_usage sont affichés pour montrer qu'ils
# ne bougent pas en nombre de lignes (claude_usage perd seulement ses liens).
_TABLES: dict[str, type] = {
    "colleges": College,
    "items": Item,
    "flash_cards": FlashCard,
    "generation_jobs": GenerationJob,
    "generation_job_events": GenerationJobEvent,
    "college_pages": CollegePage,
    "job_pages": JobPage,
    "job_items": JobItem,
    "ocr_pages": OcrPage,
    "item_texts": ItemText,
    "item_generations": ItemGeneration,
    "item_titles": ItemTitle,
    "users": User,
    "claude_usage": ClaudeUsage,
}


async def table_counts(db: AsyncSession) -> dict[str, int]:
    return {
        name: (await db.execute(select(func.count()).select_from(model))).scalar_one()
        for name, model in _TABLES.items()
    }


async def wipe_db(db: AsyncSession) -> None:
    """Supprime le contenu et remet à zéro les compteurs des utilisatrices. Ne
    commit pas (à la charge de l'appelant, une seule transaction).

    Ordre : les collèges d'abord — la cascade DB (`ON DELETE CASCADE`) supprime
    items, generation_jobs (et donc job_pages/job_items/generation_job_events),
    flash_cards, college_pages. Le stock de contenu partagé n'est alors plus
    référencé par rien et peut être vidé : item_generations avant item_texts,
    car la FK `item_generations.text_hash` n'a pas de cascade.
    """
    await db.execute(delete(College))
    await db.execute(delete(ItemGeneration))
    await db.execute(delete(ItemText))
    await db.execute(delete(OcrPage))
    await db.execute(delete(ItemTitle).where(ItemTitle.source != "official"))
    await db.execute(sql_update(User).values(monthly_reloads=0, monthly_reloads_reset_at=None))


def wipe_files(pdf_dir: Path) -> dict[str, int]:
    """Supprime les PDF (`*.pdf`, à la racine de `pdf_dir`) et le dossier
    `uploads/`. Renvoie le nombre de fichiers et de dossiers supprimés."""
    removed_pdfs = 0
    for pdf in pdf_dir.glob("*.pdf"):
        try:
            pdf.unlink(missing_ok=True)
            removed_pdfs += 1
        except OSError:
            logger.warning("PDF non supprimé : %s", pdf, exc_info=True)

    uploads_dir = pdf_dir / "uploads"
    removed_uploads = 0
    if uploads_dir.exists():
        removed_uploads = sum(1 for _ in uploads_dir.iterdir())
        shutil.rmtree(uploads_dir, ignore_errors=True)
    return {"pdfs": removed_pdfs, "uploads": removed_uploads}


def _print_report(before: dict[str, int], after: dict[str, int], files: dict[str, int]) -> None:
    print("Vidage du contenu — comptes avant / après :")
    for name in _TABLES:
        print(f"  {name:<24} {before[name]:>6} -> {after[name]:>6}")
    print(f"Fichiers supprimés : {files['pdfs']} PDF, {files['uploads']} dossier(s) uploads/")


async def run(database_url: str, pdf_dir: Path) -> None:
    engine = create_async_engine(database_url)
    try:
        session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
        async with session_factory() as db:
            before = await table_counts(db)
            await wipe_db(db)
            await db.commit()
            after = await table_counts(db)
    finally:
        await engine.dispose()
    files = wipe_files(pdf_dir)
    _print_report(before, after, files)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--confirm", action="store_true", help="confirme le vidage (sinon : refus, rien n'est touché)")
    args = parser.parse_args(argv)
    if not args.confirm:
        print("Vidage refusé : relancer avec --confirm.", file=sys.stderr)
        return 1
    asyncio.run(run(settings.database_url, Path(settings.pdf_storage_path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
