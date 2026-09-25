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

Chantier 4 : items générés en parallèle (`settings.generation_concurrency` appels
simultanés), chacun dans sa tâche avec ses sessions courtes et son commit ; seul
l'orchestrateur tient l'avancement (items faits, fiches, aperçu). Stop : constaté par
chaque tâche avant son appel ; les appels en vol sont alors annulés — un appel déjà
revenu est tout de même enregistré (payé, réutilisable) —, les items validés restent
acquis et la bascule n'a pas lieu (publish_job ignore un job qui n'est plus
`ocr_complete`).
Erreur d'une tâche (API indisponible après les réessais du SDK) : les autres sont
annulées et l'erreur remonte (le worker passe l'import en échec, `fail_job`).
Les pages de l'item sont relues dans `item_texts` (séparateur de page stable,
`store.PAGE_SEPARATOR`) pour que `clean_for_prompt` traite les en-têtes répétés.
Texte insuffisant : génération à 0 fiche conservée (jamais repayée), item marqué
`job_items.insufficient_text` et listé dans le résumé d'import.
"""

from __future__ import annotations

import asyncio
import itertools
import json
import logging
import uuid
from collections.abc import Awaitable, Callable, Iterator, Sequence
from dataclasses import dataclass
from typing import Any

from sqlalchemy import func, select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import settings
from app.models.college import College
from app.models.content import ItemGeneration, JobItem
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.services.content import store
from app.services.generation.claude_client import GENERATION_MODEL, GENERATION_VERSION, CardGenResult
from app.services.generation.usage import record_usage
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


async def _report(progress: ProgressReporter | None, college_id: uuid.UUID, **kw: Any) -> None:
    """L'avancement n'est qu'un affichage : son échec n'arrête jamais la génération."""
    if progress is None:
        return
    try:
        await progress(college_id, **kw)
    except Exception:  # noqa: BLE001
        logger.warning("Avancement de génération non publié (college %s)", college_id, exc_info=True)


async def _job_status(db: AsyncSession, job_id: uuid.UUID) -> str | None:
    return (await db.execute(select(GenerationJob.status).where(GenerationJob.id == job_id))).scalar_one_or_none()


async def generate_job_items(
    session_factory: async_sessionmaker[AsyncSession],
    job_id: uuid.UUID,
    claude: Any,
    progress: ProgressReporter | None = None,
) -> int | None:
    """Renvoie le nombre d'appels Claude de cette exécution, ou None si l'import a
    été arrêté (Stop, job ou collège supprimé)."""
    async with session_factory() as db:
        job = await db.get(GenerationJob, job_id)
        if job is None:
            return None
        college_id, user_id = job.college_id, job.user_id
        drafts = (
            (await db.execute(select(JobItem).where(JobItem.job_id == job_id).order_by(JobItem.item_number)))
            .scalars()
            .all()
        )
        done_gen_ids = [d.generation_id for d in drafts if d.generation_id is not None]
        done_gens = (
            (await db.execute(select(ItemGeneration).where(ItemGeneration.id.in_(done_gen_ids)))).scalars().all()
            if done_gen_ids
            else []
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

    todo = [(d.item_number, d.chapter_title, d.text_hash) for d in drafts if d.generation_id is None and not kept(d)]
    total = len(drafts)
    items_done = total - len(todo)
    cards = sum(len(store.generation_cards(g)) for g in done_gens) + sum(
        live[d.item_number][1] for d in drafts if d.generation_id is None and kept(d)
    )
    latest: list[str] = []
    claude_calls = 0
    await _report(progress, college_id, items_done=items_done, items_total=total, cards=cards, preview=latest)

    semaphore = asyncio.Semaphore(settings.generation_concurrency)
    event_numbers = itertools.count(items_done + 1)

    async def generate_one(item_number: int, title: str | None, text_hash: str) -> _ItemOutcome | None:
        async with semaphore:
            return await _generate_item(
                session_factory,
                claude,
                job_id=job_id,
                user_id=user_id,
                college_id=college_id,
                item_number=item_number,
                title=title,
                text_hash=text_hash,
                total=total,
                event_numbers=event_numbers,
            )

    pending = {asyncio.create_task(generate_one(*t), name=f"generation-item-{t[0]}") for t in todo}
    try:
        while pending:
            done, pending = await asyncio.wait(pending, return_when=asyncio.FIRST_COMPLETED)
            # Erreur ou annulation d'une tâche : les autres sont annulées (finally), le job
            # échoue par l'appelant (fail_job) ou reste reprenable (CancelledError).
            failed = [t for t in done if t.cancelled() or t.exception() is not None]
            if failed:
                primary = _primary_failure(failed)
                for other in failed:
                    if other is not primary:
                        _log_task_error(other)
                primary.result()
            results = [t.result() for t in done]
            outcomes = [o for o in results if o is not None]
            if len(outcomes) < len(results):
                return None  # Stop, job ou collège supprimé
            # Seul l'orchestrateur tient les compteurs d'avancement.
            for outcome in outcomes:
                claude_calls += outcome.billed
                items_done += 1
                cards += len(outcome.cards)
                latest = ([c["recto"] for c in reversed(outcome.cards)] + latest)[:PREVIEW_SIZE]
            await _report(progress, college_id, items_done=items_done, items_total=total, cards=cards, preview=latest)
    finally:
        # Stop, erreur ou interruption du worker : les appels en vol sont abandonnés ;
        # les items déjà validés restent acquis (reprise sans repayer).
        for task in pending:
            task.cancel()
        if pending:
            await asyncio.gather(*pending, return_exceptions=True)
            for task in pending:
                _log_task_error(task)

    return claude_calls


def _primary_failure(failed: list[asyncio.Task[Any]]) -> asyncio.Task[Any]:
    """Choisit la tâche à remonter dans un lot où plusieurs ont échoué. Une tâche
    annulée seulement parce qu'une autre échouait ne doit jamais masquer l'erreur
    réelle (sinon `fail_job` reçoit une CancelledError au lieu de la vraie cause) :
    priorité à une tâche en erreur ; à défaut, la première tâche annulée."""
    return next((t for t in failed if not t.cancelled()), failed[0])


def _log_task_error(task: asyncio.Task[Any]) -> None:
    """Journalise l'erreur d'une tâche d'item qui n'est pas celle qui remonte (jamais
    « Task exception was never retrieved ») ; une annulation n'est pas une erreur."""
    if task.done() and not task.cancelled() and (exc := task.exception()) is not None:
        logger.warning("Génération : autre erreur (%s) : %r", task.get_name(), exc)


@dataclass
class _ItemOutcome:
    cards: list[dict[str, Any]]
    billed: bool


async def _generate_item(
    session_factory: async_sessionmaker[AsyncSession],
    claude: Any,
    *,
    job_id: uuid.UUID,
    user_id: uuid.UUID,
    college_id: uuid.UUID,
    item_number: int,
    title: str | None,
    text_hash: str,
    total: int,
    event_numbers: Iterator[int],
) -> _ItemOutcome | None:
    """Génère (ou réutilise) la génération d'un item et la valide aussitôt (commit
    par item). None : import arrêté (Stop constaté avant l'appel, job supprimé)."""
    async with session_factory() as db:
        if await _job_status(db, job_id) != "ocr_complete":
            logger.info("Génération du job %s arrêtée avant l'item %d", job_id, item_number)
            return None
        gen = await store.find_generation(db, text_hash, GENERATION_VERSION)
        pages = None if gen is not None else await store.get_item_pages(db, text_hash)

    result = None
    if gen is None:
        result = await claude.generate_cards(item_number, title or "", pages or [""])

    # L'appel est payé : son enregistrement (usage, génération, brouillon) va au bout
    # même si la tâche est annulée entre-temps (Stop, erreur d'un autre item, arrêt
    # du worker) — sinon un réimport le repaierait. L'annulation est rendue ensuite.
    persist = asyncio.ensure_future(
        _persist_item(
            session_factory,
            result,
            gen,
            job_id=job_id,
            user_id=user_id,
            college_id=college_id,
            item_number=item_number,
            text_hash=text_hash,
            total=total,
            event_numbers=event_numbers,
        )
    )
    try:
        return await asyncio.shield(persist)
    except asyncio.CancelledError:
        # Une deuxième annulation peut arriver pendant qu'on attend la fin de la
        # persistance (elle aussi doit être protégée, sinon l'appel payé risque de
        # ne jamais être enregistré) : on reste protégé jusqu'à ce que `persist`
        # soit vraiment terminée, puis on relaie l'annulation reçue ici (celle de
        # cette tâche, pas un échec de `persist`, journalisé ci-dessous s'il y en
        # a un — jamais perdu silencieusement).
        while not persist.done():
            try:
                await asyncio.shield(persist)
            except asyncio.CancelledError:
                continue
            except Exception:  # noqa: BLE001 — retrouvé ci-dessous via persist.exception()
                continue
        if not persist.cancelled() and (exc := persist.exception()) is not None:
            logger.warning(
                "Item %d : persistance en échec après annulation (sera retentée au prochain import) : %r",
                item_number,
                exc,
            )
        raise


async def _persist_item(
    session_factory: async_sessionmaker[AsyncSession],
    result: CardGenResult | None,
    gen: ItemGeneration | None,
    *,
    job_id: uuid.UUID,
    user_id: uuid.UUID,
    college_id: uuid.UUID,
    item_number: int,
    text_hash: str,
    total: int,
    event_numbers: Iterator[int],
) -> _ItemOutcome | None:
    """Enregistre l'usage de l'appel, la génération et le brouillon, commit par item.

    Pas de contrôle du Stop ici : un résultat payé est toujours enregistré (il sera
    réutilisé sans repayer) ; un job arrêté n'est de toute façon jamais basculé
    (publish_job relit son statut sous verrou). None : job supprimé."""
    if result is not None and (result.input_tokens or result.output_tokens):
        # Seul un appel réellement facturé compte (texte vide : aucun appel fait). Il est
        # enregistré tout de suite : compté même si l'import est ensuite arrêté ou échoue.
        await record_usage(
            session_factory,
            kind="generation",
            model=result.model,
            input_tokens=result.input_tokens,
            output_tokens=result.output_tokens,
            user_id=user_id,
            college_id=college_id,
            job_id=job_id,
        )

    async with session_factory() as db:
        job = await db.get(GenerationJob, job_id)
        if job is None:
            return None
        if result is not None:
            if result.cards or result.insufficient_text:
                # Texte insuffisant : génération à 0 fiche gardée comme les autres (et
                # épargnée par la purge) — un réimport du même texte ne repaie pas l'item.
                gen = await store.put_generation(
                    db,
                    text_hash,
                    GENERATION_VERSION,
                    [
                        {"card_type": c.card_type, "rang": c.rang, "recto": c.recto, "verso": c.verso}
                        for c in result.cards
                    ],
                    GENERATION_MODEL,
                    result.input_tokens,
                    result.output_tokens,
                    insufficient_text=result.insufficient_text,
                )
            else:
                logger.warning("Item %d : aucune fiche exploitable (sera retenté au prochain import)", item_number)
        if gen is not None:
            await db.execute(
                sa_update(JobItem)
                .where(JobItem.job_id == job_id, JobItem.item_number == item_number)
                .values(generation_id=gen.id, insufficient_text=gen.insufficient_text)
            )
        # Un événement par item : trace pour l'admin et « progression » pour le cron
        # des jobs bloqués (la console n'affiche que le dernier d'une série).
        await record_job_event(
            db, job_id, "generation_progress", message=f"item {item_number}", page=next(event_numbers), total=total
        )
        await db.commit()

    billed = result is not None and bool(result.input_tokens or result.output_tokens)
    return _ItemOutcome(cards=store.generation_cards(gen) if gen is not None else [], billed=billed)
