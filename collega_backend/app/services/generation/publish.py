"""Bascule d'un import vers le contenu en service (chantier 1).

Une seule transaction, collège verrouillé. Items rapprochés par numéro :
- inchangé (même empreinte) : métadonnées rafraîchies, fiches intactes (identifiants,
  pouces, régénérations et suppressions de l'utilisatrice conservés) ; s'il n'avait
  aucune fiche et qu'une génération est prête, ses fiches sont ajoutées ;
- modifié : item conservé (même id), fiches remplacées par la génération — sans
  génération exploitable, l'ancien contenu est gardé tel quel (retenté plus tard) ;
- nouveau : item + fiches créés ;
- disparu : item supprimé (fiches en cascade) — sauf si plus de la moitié des items
  disparaissent d'un réimport : mauvais PDF probable, rien n'est modifié
  (`ImportRejected`).
Rejouable : un import qui n'est plus `ocr_complete` (déjà basculé, stoppé) n'est
pas republié. Ne commit pas (l'appelant commit), ne touche à aucun fichier.
"""

from __future__ import annotations

import json
import logging
import uuid
from dataclasses import asdict, dataclass
from pathlib import Path

from sqlalchemy import delete, func, select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.college import College, CollegeStatus
from app.models.content import CollegePage, ItemGeneration, JobItem, JobPage
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.services.content.store import generation_cards
from app.services.jobs.job_events import record_job_event

logger = logging.getLogger(__name__)


# Garde-fou « mauvais PDF » : au-delà de cette part d'items disparus, un réimport
# est refusé (à partir de MIN_ITEMS_FOR_GUARD items en service).
MAX_REMOVED_SHARE = 0.5
MIN_ITEMS_FOR_GUARD = 4


class ImportRejected(Exception):
    """Bascule refusée sans rien modifier ; le message est destiné à l'utilisatrice."""


@dataclass
class ImportSummary:
    changed: int = 0
    added: int = 0
    removed: int = 0
    unchanged: int = 0
    cards: int = 0
    claude_calls: int = 0
    quota_refunded: bool = False
    reimport: bool = False

    def as_dict(self) -> dict:
        return asdict(self)


def stale_pdfs(college_id: uuid.UUID, keep_job_id: uuid.UUID) -> list[Path]:
    """PDF du collège autres que celui de l'import qui vient d'être publié."""
    keep = f"{college_id}_{keep_job_id}.pdf"
    return sorted(p for p in Path(settings.pdf_storage_path).glob(f"{college_id}_*.pdf") if p.name != keep)


def _copy_metadata(item: Item, draft: JobItem) -> None:
    item.rang = draft.rang
    item.chapter_title = draft.chapter_title
    item.start_page = draft.start_page
    item.end_page = draft.end_page
    item.ocr_confidence_score = draft.ocr_confidence_score
    item.low_confidence = draft.low_confidence


async def publish_job(db: AsyncSession, job_id: uuid.UUID, *, claude_calls: int) -> ImportSummary | None:
    job = (await db.execute(select(GenerationJob).where(GenerationJob.id == job_id))).scalar_one_or_none()
    if job is None:
        return None
    college = (
        await db.execute(select(College).where(College.id == job.college_id).with_for_update())
    ).scalar_one_or_none()
    # Relecture du job sous verrou : un Stop concurrent a pu le passer en échec.
    job = (
        await db.execute(select(GenerationJob).where(GenerationJob.id == job_id).with_for_update())
    ).scalar_one_or_none()
    if college is None or job is None or job.status != "ocr_complete":
        return None

    was_ready = college.status == CollegeStatus.generation_complete
    drafts = {d.item_number: d for d in (await db.execute(select(JobItem).where(JobItem.job_id == job_id))).scalars()}
    live = {i.item_number: i for i in (await db.execute(select(Item).where(Item.college_id == college.id))).scalars()}
    gen_ids = {d.generation_id for d in drafts.values() if d.generation_id is not None}
    generations = (
        {g.id: g for g in (await db.execute(select(ItemGeneration).where(ItemGeneration.id.in_(gen_ids)))).scalars()}
        if gen_ids
        else {}
    )

    card_counts: dict[uuid.UUID, int] = dict(
        (
            await db.execute(
                select(FlashCard.item_id, func.count(FlashCard.id))
                .where(FlashCard.college_id == college.id)
                .group_by(FlashCard.item_id)
            )
        )
        .tuples()
        .all()
    )
    removed_numbers = [n for n in live if n not in drafts]
    if was_ready and len(live) >= MIN_ITEMS_FOR_GUARD and len(removed_numbers) > len(live) * MAX_REMOVED_SHARE:
        raise ImportRejected(
            f"Ce PDF ne semble pas correspondre à ce collège : {len(removed_numbers)} items sur {len(live)} "
            "en disparaîtraient. Rien n'a été modifié."
        )

    summary = ImportSummary(claude_calls=claude_calls, reimport=was_ready)

    def add_cards(item: Item, draft: JobItem) -> None:
        gen = generations.get(draft.generation_id) if draft.generation_id else None
        if gen is None:
            return
        for c in generation_cards(gen):
            db.add(
                FlashCard(
                    item_id=item.id,
                    college_id=college.id,
                    user_id=college.user_id,
                    card_type=c["card_type"],
                    rang=item.rang,
                    recto=c["recto"],
                    verso=c["verso"],
                    ocr_confidence_score=item.ocr_confidence_score,
                    low_confidence=item.low_confidence,
                    generation_id=gen.id,
                )
            )

    for number, draft in sorted(drafts.items()):
        item = live.get(number)
        if item is None:
            item = Item(id=uuid.uuid4(), college_id=college.id, item_number=number, text_hash=draft.text_hash)
            _copy_metadata(item, draft)
            db.add(item)
            await db.flush()
            add_cards(item, draft)
            summary.added += 1
        elif item.text_hash == draft.text_hash:
            _copy_metadata(item, draft)
            if card_counts.get(item.id, 0) == 0 and draft.generation_id is not None:
                add_cards(item, draft)  # item resté sans fiche : il en reçoit enfin
                summary.changed += 1
            else:
                summary.unchanged += 1
        elif draft.generation_id is None:
            # Modifié mais Claude n'a rien rendu d'exploitable : on garde l'ancien
            # contenu (et son empreinte) plutôt que de le perdre ; retenté au prochain import.
            _copy_metadata(item, draft)
            logger.warning("Item %d modifié sans génération : ancien contenu conservé", number)
            summary.unchanged += 1
        else:
            _copy_metadata(item, draft)
            item.text_hash = draft.text_hash
            await db.execute(delete(FlashCard).where(FlashCard.item_id == item.id))
            add_cards(item, draft)
            summary.changed += 1

    for number in removed_numbers:
        await db.delete(live[number])
        summary.removed += 1
    await db.flush()

    await db.execute(delete(CollegePage).where(CollegePage.college_id == college.id))
    pages = (await db.execute(select(JobPage).where(JobPage.job_id == job_id))).scalars().all()
    db.add_all(CollegePage(college_id=college.id, page_number=p.page_number, page_hash=p.page_hash) for p in pages)
    await db.execute(delete(JobItem).where(JobItem.job_id == job_id))
    await db.execute(delete(JobPage).where(JobPage.job_id == job_id))

    if was_ready and claude_calls == 0:
        # Réimport sans aucun appel Claude (même contenu, tout réutilisé) : le quota
        # consommé au router est rendu. UPDATE conditionnels `> 0` : jamais négatif.
        await db.execute(
            sa_update(College)
            .where(College.id == college.id)
            .where(College.reload_count > 0)
            .values(reload_count=College.reload_count - 1)
        )
        await db.execute(
            sa_update(User)
            .where(User.id == job.user_id)
            .where(User.monthly_reloads > 0)
            .values(monthly_reloads=User.monthly_reloads - 1)
        )
        summary.quota_refunded = True

    summary.cards = (
        await db.execute(select(func.count()).select_from(FlashCard).where(FlashCard.college_id == college.id))
    ).scalar_one()
    job.status = "generation_complete"
    job.card_count = summary.cards
    job.hash_shared = claude_calls == 0
    job.summary_json = json.dumps(summary.as_dict())
    college.status = CollegeStatus.generation_complete
    college.generation_items_total = None
    await record_job_event(
        db,
        job_id,
        "generation_complete",
        message=(
            f"{summary.changed} modifiés, {summary.added} nouveaux, {summary.removed} supprimés, "
            f"{summary.unchanged} inchangés — {summary.cards} fiches"
        ),
    )
    logger.info("Import %s publié : %s", job_id, summary.as_dict())
    return summary
