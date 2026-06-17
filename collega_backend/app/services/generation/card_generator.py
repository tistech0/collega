from __future__ import annotations

import logging
import uuid

from sqlalchemy import delete, select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.services.generation.claude_client import ClaudeClient
from app.services.generation.hash_sharing import SHA256SimilarityChecker
from app.services.jobs.job_events import record_job_event

logger = logging.getLogger(__name__)


class CardGenerator:
    def __init__(self) -> None:
        self._claude = ClaudeClient()
        self._similarity = SHA256SimilarityChecker()

    async def generate_for_college(
        self,
        db: AsyncSession,
        college_id: uuid.UUID,
        job_id: uuid.UUID,
        pdf_path: str,
    ) -> dict:
        job = await db.get(GenerationJob, job_id)
        if job is None:
            raise ValueError(f"GenerationJob {job_id} not found")

        # Jalon timeline (review 7.7 P1) : écrit à l'entrée pour couvrir TOUS les
        # chemins, y compris le hash-sharing qui retournait avant l'ancien point
        # d'écriture (timeline incomplète : ocr_* → generation_complete sans start).
        await record_job_event(db, job_id, "generation_started")

        # Idempotency: delete any existing cards before generating (handles ARQ retries)
        await db.execute(delete(FlashCard).where(FlashCard.college_id == college_id))

        pdf_hash = self._similarity.compute_hash(pdf_path)
        job.pdf_hash = pdf_hash

        similar_job = await self._similarity.find_similar_job(db, pdf_hash)

        if similar_job is not None and similar_job.id != job_id:
            count = await self._copy_cards_for_hash_sharing(
                db, similar_job, college_id, job.user_id
            )
            if count > 0:
                job.hash_shared = True
                job.card_count = count
                job.status = "generation_complete"
                # Story 7.2 — Décision review : pour un reimport servi par
                # hash-sharing (Claude PAS appelé, gratuit), on compense le
                # quota incrémenté au router. UPDATE conditionnel `> 0` évite
                # tout underflow si un autre flow décrémentait en parallèle.
                if await self._is_reimport(db, college_id, job_id):
                    await db.execute(
                        sa_update(College)
                        .where(College.id == college_id)
                        .where(College.reload_count > 0)
                        .values(reload_count=College.reload_count - 1)
                    )
                    await db.execute(
                        sa_update(User)
                        .where(User.id == job.user_id)
                        .where(User.monthly_reloads > 0)
                        .values(monthly_reloads=User.monthly_reloads - 1)
                    )
                    logger.info(
                        "Hash-sharing reimport: quota compensé (college %s, user %s)",
                        college_id,
                        job.user_id,
                    )
                await record_job_event(
                    db, job_id, "generation_complete", message=f"{count} cards (hash-sharing)"
                )
                await db.commit()
                logger.info(
                    "Hash-sharing: copied %d cards for college %s from job %s",
                    count,
                    college_id,
                    similar_job.id,
                )
                return {"college_id": str(college_id), "job_id": str(job_id), "hash_shared": True, "card_count": count}
            else:
                logger.warning(
                    "Hash-sharing from job %s returned 0 cards — falling through to normal generation",
                    similar_job.id,
                )

        items_result = await db.execute(
            select(Item).where(Item.college_id == college_id)
        )
        items = items_result.scalars().all()

        card_count = 0
        for item in items:
            # Garde anti-race (review 7.7 D1) : si l'admin a forcé l'arrêt
            # (Stop → status="failed") pendant la génération, stopper avant le
            # prochain appel Claude (évite de payer pour un job annulé) et ne pas
            # écraser le statut. La transaction non commitée est rollback à la
            # fermeture de session → aucune fiche partielle persistée.
            current_status = (
                await db.execute(
                    select(GenerationJob.status).where(GenerationJob.id == job_id)
                )
            ).scalar_one_or_none()
            if current_status == "failed":
                logger.info(
                    "Génération du job %s annulée par l'admin — arrêt (%d fiches générées avant annulation)",
                    job_id,
                    card_count,
                )
                return {
                    "college_id": str(college_id),
                    "job_id": str(job_id),
                    "hash_shared": False,
                    "card_count": card_count,
                    "cancelled": True,
                }

            cards_data = await self._claude.generate_cards_for_item(item)
            if not cards_data:
                logger.warning("Item %s produced 0 cards — skipping", item.id)
                continue
            for card_data in cards_data:
                card = FlashCard(
                    item_id=item.id,
                    college_id=college_id,
                    user_id=job.user_id,
                    card_type=card_data.card_type,
                    rang=item.rang,
                    recto=card_data.recto,
                    verso=card_data.verso,
                    ocr_confidence_score=item.ocr_confidence_score,
                    low_confidence=item.low_confidence,
                )
                db.add(card)
                card_count += 1

        job.card_count = card_count
        job.status = "generation_complete"

        # Note: reload_count / monthly_reloads sont incrémentés atomiquement au router
        # (app/api/v1/colleges.py:import_college_pdf) AVANT la création du job.
        # Cf. story 7.2 — A1 : éviter le double-comptage et éviter de payer Claude pour rien.

        await record_job_event(
            db, job_id, "generation_complete", message=f"{card_count} cards"
        )
        await db.commit()

        logger.info(
            "Generation complete for college %s — %d cards created",
            college_id,
            card_count,
        )
        return {"college_id": str(college_id), "job_id": str(job_id), "hash_shared": False, "card_count": card_count}

    async def _is_reimport(
        self,
        db: AsyncSession,
        college_id: uuid.UUID,
        current_job_id: uuid.UUID,
    ) -> bool:
        """True si ce college a déjà eu un job terminé (autre que le courant).

        Utilisé pour décider si l'on doit compenser le quota après hash-sharing :
        un premier import ne consomme pas de quota au router (la branche
        `if college.status == "generation_complete"` ne match qu'en reimport),
        donc rien à rendre.
        """
        prior = await db.execute(
            select(GenerationJob.id)
            .where(GenerationJob.college_id == college_id)
            .where(GenerationJob.id != current_job_id)
            .where(GenerationJob.status == "generation_complete")
            .limit(1)
        )
        return prior.scalar_one_or_none() is not None

    async def _copy_cards_for_hash_sharing(
        self,
        db: AsyncSession,
        source_job: GenerationJob,
        target_college_id: uuid.UUID,
        target_user_id: uuid.UUID,
    ) -> int:
        source_cards_result = await db.execute(
            select(FlashCard).where(FlashCard.college_id == source_job.college_id)
        )
        source_cards = source_cards_result.scalars().all()

        target_items_result = await db.execute(
            select(Item).where(Item.college_id == target_college_id)
        )
        target_items = {item.item_number: item for item in target_items_result.scalars().all()}

        source_items_result = await db.execute(
            select(Item).where(Item.college_id == source_job.college_id)
        )
        source_items = {item.id: item for item in source_items_result.scalars().all()}

        count = 0
        for card in source_cards:
            source_item = source_items.get(card.item_id)
            if source_item is None:
                continue
            target_item = target_items.get(source_item.item_number)
            if target_item is None:
                continue
            new_card = FlashCard(
                item_id=target_item.id,
                college_id=target_college_id,
                user_id=target_user_id,
                card_type=card.card_type,
                rang=card.rang,
                recto=card.recto,
                verso=card.verso,
                ocr_confidence_score=card.ocr_confidence_score,
                low_confidence=card.low_confidence,
            )
            db.add(new_card)
            count += 1

        # No commit here — caller owns the transaction boundary
        return count
