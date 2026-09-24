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

Refuse de tourner (rien n'est touché, code de sortie 1) :
- sans `--confirm` ;
- si un import est en cours (`generation_jobs.status` dans
  `app.services.imports.ACTIVE_JOB_STATUSES` : `pending`, `processing`,
  `ocr_complete`) — un job en vol perdrait son collège en cours d'écriture.
  Arrêter le worker avant de vider (`docker compose stop worker`), le
  relancer après (`docker compose start worker`) : c'est le worker qui fait
  avancer un import, pas l'api.

Redis : rien à vider — le chantier 4 n'y stocke aucun contenu, seulement des
verrous et de l'état d'upload à courte durée de vie (TTL) et le rate
limiting. Les clés d'upload par morceaux (Story 7.11) qui pointaient vers un
dossier `uploads/<id>` maintenant supprimé expirent d'elles-mêmes (TTL) ; rien
à purger côté Redis pour elles.

Un seul commit pour la partie base ; les fichiers ne sont supprimés qu'après
ce commit. Affiche les comptes avant/après (table et nombre seulement, jamais
de texte de page ou de fiche).

Invocation dans le conteneur api (l'image contient `scripts/`) — EN MODULE,
pas en chemin de fichier : lancé comme fichier (`python scripts/wipe_content.py`),
`sys.path[0]` devient `/app/scripts` et l'import `from app.core.config import
settings` échoue (`ModuleNotFoundError: app`) :

  docker compose stop worker
  docker exec collega-api-1 python -m scripts.wipe_content --confirm
  docker compose start worker
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
from app.services.imports import ACTIVE_JOB_STATUSES

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


async def count_active_jobs(db: AsyncSession) -> int:
    """Imports en cours (`ACTIVE_JOB_STATUSES`) : un vidage pendant l'un d'eux
    supprimerait le collège sous les pieds du worker qui le traite."""
    return (
        await db.execute(
            select(func.count()).select_from(GenerationJob).where(GenerationJob.status.in_(ACTIVE_JOB_STATUSES))
        )
    ).scalar_one()


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
    `uploads/`. Renvoie le nombre de fichiers et de dossiers réellement
    supprimés (jamais ce qu'on a tenté : un échec est compté « non supprimé »
    et journalisé, pas rapporté comme fait)."""
    removed_pdfs = 0
    for pdf in pdf_dir.glob("*.pdf"):
        try:
            pdf.unlink()  # le fichier vient d'être listé : une disparition entre-temps est une vraie erreur
            removed_pdfs += 1
        except OSError:
            logger.warning("PDF non supprimé : %s", pdf, exc_info=True)

    uploads_dir = pdf_dir / "uploads"
    removed_uploads = 0
    if uploads_dir.exists():
        before = set(uploads_dir.iterdir())
        try:
            shutil.rmtree(uploads_dir)
        except OSError:
            logger.warning("uploads/ non entièrement supprimé : %s", uploads_dir, exc_info=True)
        after = set(uploads_dir.iterdir()) if uploads_dir.exists() else set()
        removed_uploads = len(before - after)
    return {"pdfs": removed_pdfs, "uploads": removed_uploads}


def _print_report(before: dict[str, int], after: dict[str, int], files: dict[str, int]) -> None:
    print("Vidage du contenu — comptes avant / après :")
    for name in _TABLES:
        print(f"  {name:<24} {before[name]:>6} -> {after[name]:>6}")
    print(f"Fichiers supprimés : {files['pdfs']} PDF, {files['uploads']} dossier(s) uploads/")


async def run(database_url: str, pdf_dir: Path) -> int:
    """Renvoie le code de sortie : 0 fait, 1 refusé (rien touché — import en cours)."""
    engine = create_async_engine(database_url)
    try:
        session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
        async with session_factory() as db:
            active = await count_active_jobs(db)
            if active:
                print(
                    f"Vidage refusé : {active} import(s) en cours. Arrêter le worker"
                    " (docker compose stop worker) et réessayer.",
                    file=sys.stderr,
                )
                return 1
            before = await table_counts(db)
            await wipe_db(db)
            await db.commit()
            after = await table_counts(db)
    finally:
        await engine.dispose()
    files = wipe_files(pdf_dir)
    _print_report(before, after, files)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--confirm", action="store_true", help="confirme le vidage (sinon : refus, rien n'est touché)")
    args = parser.parse_args(argv)
    if not args.confirm:
        print("Vidage refusé : relancer avec --confirm.", file=sys.stderr)
        return 1
    return asyncio.run(run(settings.database_url, Path(settings.pdf_storage_path)))


if __name__ == "__main__":
    sys.exit(main())
