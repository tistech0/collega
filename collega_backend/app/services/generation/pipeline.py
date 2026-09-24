"""Génération des fiches d'un import, item par item (chantier 1).

Pour chaque item du brouillon (`job_items`) :
- item inchangé (même empreinte que l'item en service) qui a déjà des fiches →
  rien à générer : la bascule garde ses fiches (c'est le cas des collèges
  remplis par scripts.backfill_content_store, qui n'ont pas de génération) ;
- une génération existe déjà pour (empreinte du texte, version de génération) —
  item inchangé, même PDF chez une autre utilisatrice, ou tentative précédente
  interrompue — → réutilisée, sans appel Claude ;
- sinon appel Claude, sortie d'origine enregistrée (`item_generations`) et
  validée immédiatement : une relance (crash, redéploiement) ne repaie jamais un
  item déjà généré.
Aucune session n'est ouverte pendant un appel Claude.
"""
from __future__ import annotations

import json
import logging
import uuid
from collections.abc import Awaitable, Callable, Sequence

from sqlalchemy import func, select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.college import College
from app.models.content import ItemGeneration, JobItem
from app.models.flash_card import FlashCard
from app.models.item import Item
from app.models.generation_job import GenerationJob
from app.services.content import store
from app.services.generation.claude_client import GENERATION_MODEL, GENERATION_VERSION
from app.services.jobs.job_events import record_job_event

logger = logging.getLogger(__name__)

ProgressReporter = Callable[..., Awaitable[None]]
PREVIEW_SIZE = 3


async def report_generation_progress(
    college_id: uuid.UUID, *, items_done: int, items_total: int | None, cards: int, preview: Sequence[str] = ()
) -> None:
    """Publie l'avancement (story 8.13) dans une session à part, commit immédiat."""
    from app.core.database import async_session_factory

    async with async_session_factory() as session:
        await session.execute(
            sa_update(College)
            .where(College.id == college_id)
            .values(
                generation_items_done=items_done,
                generation_items_total=items_total,
                generation_cards=cards,
                generation_preview=json.dumps(list(preview), ensure_ascii=False),
            )
        )
        await session.commit()


async def _report(progress: ProgressReporter | None, college_id: uuid.UUID, **kw) -> None:
    """L'avancement n'est qu'un affichage : son échec n'arrête jamais la génération."""
    if progress is None:
        return
    try:
        await progress(college_id, **kw)
    except Exception:  # noqa: BLE001
        logger.warning("Avancement de génération non publié (college %s)", college_id, exc_info=True)


async def _job_status(db: AsyncSession, job_id: uuid.UUID) -> str | None:
    return (
        await db.execute(select(GenerationJob.status).where(GenerationJob.id == job_id))
    ).scalar_one_or_none()


async def generate_job_items(
    session_factory: async_sessionmaker[AsyncSession],
    job_id: uuid.UUID,
    claude,
    progress: ProgressReporter | None = None,
) -> int | None:
    """Renvoie le nombre d'appels Claude de cette exécution, ou None si l'import a
    été arrêté (Stop, job ou collège supprimé)."""
    async with session_factory() as db:
        job = await db.get(GenerationJob, job_id)
        if job is None:
            return None
        college_id = job.college_id
        drafts = (
            await db.execute(select(JobItem).where(JobItem.job_id == job_id).order_by(JobItem.item_number))
        ).scalars().all()
        done_gen_ids = [d.generation_id for d in drafts if d.generation_id is not None]
        done_gens = (
            (await db.execute(select(ItemGeneration).where(ItemGeneration.id.in_(done_gen_ids)))).scalars().all()
            if done_gen_ids else []
        )
        # Items en service : (empreinte, nombre de fiches), par numéro.
        live = {
            number: (text_hash, count)
            for number, text_hash, count in (
                await db.execute(
                    select(Item.item_number, Item.text_hash, func.count(FlashCard.id))
                    .outerjoin(FlashCard, FlashCard.item_id == Item.id)
                    .where(Item.college_id == college_id)
                    .group_by(Item.id)
                )
            ).all()
        }

    def kept(d: JobItem) -> bool:
        """Inchangé et déjà pourvu en fiches : la bascule les garde, rien à générer."""
        text_hash, count = live.get(d.item_number, (None, 0))
        return text_hash == d.text_hash and count > 0

    todo = [(d.item_number, d.rang, d.text_hash) for d in drafts if d.generation_id is None and not kept(d)]
    total = len(drafts)
    items_done = total - len(todo)
    cards = sum(len(store.generation_cards(g)) for g in done_gens) + sum(
        live[d.item_number][1] for d in drafts if d.generation_id is None and kept(d)
    )
    latest: list[str] = []
    claude_calls = 0
    await _report(progress, college_id, items_done=items_done, items_total=total, cards=cards, preview=latest)

    for item_number, rang, text_hash in todo:
        async with session_factory() as db:
            if await _job_status(db, job_id) != "ocr_complete":
                logger.info("Génération du job %s arrêtée avant l'item %d", job_id, item_number)
                return None
            gen = await store.find_generation(db, text_hash, GENERATION_VERSION)
            text = None if gen is not None else await store.get_item_text(db, text_hash)

        result = None
        if gen is None:
            result = await claude.generate_cards(item_number, rang, text or "")
            # Seul un appel réellement facturé compte (texte vide : aucun appel fait).
            if result.input_tokens or result.output_tokens:
                claude_calls += 1

        async with session_factory() as db:
            job = await db.get(GenerationJob, job_id)
            if job is None:
                return None
            if result is not None:
                # Tokens facturés même sans fiche exploitable (réponse illisible).
                job.input_tokens = (job.input_tokens or 0) + result.input_tokens
                job.output_tokens = (job.output_tokens or 0) + result.output_tokens
                if result.cards:
                    gen = await store.put_generation(
                        db,
                        text_hash,
                        GENERATION_VERSION,
                        [{"card_type": c.card_type, "recto": c.recto, "verso": c.verso} for c in result.cards],
                        GENERATION_MODEL,
                        result.input_tokens,
                        result.output_tokens,
                    )
                else:
                    logger.warning("Item %d : aucune fiche exploitable (sera retenté au prochain import)", item_number)
            if gen is not None:
                await db.execute(
                    sa_update(JobItem)
                    .where(JobItem.job_id == job_id, JobItem.item_number == item_number)
                    .values(generation_id=gen.id)
                )
            # Un événement par item : trace pour l'admin et « progression » pour le cron
            # des jobs bloqués (la console n'affiche que le dernier d'une série).
            await record_job_event(
                db, job_id, "generation_progress", message=f"item {item_number}", page=items_done + 1, total=total
            )
            await db.commit()

        items_done += 1
        if gen is not None:
            new_cards = store.generation_cards(gen)
            cards += len(new_cards)
            latest = ([c["recto"] for c in reversed(new_cards)] + latest)[:PREVIEW_SIZE]
        await _report(progress, college_id, items_done=items_done, items_total=total, cards=cards, preview=latest)

    return claude_calls
