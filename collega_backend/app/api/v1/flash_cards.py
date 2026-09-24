"""Endpoints de feedback, suppression et régénération de fiches — FR19, FR20, FR21."""

from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import database
from app.core.database import get_db
from app.core.errors import AppError, conflict, not_found, unprocessable
from app.core.limiter import limiter
from app.deps import require_subscription
from app.models.flash_card import FlashCard
from app.models.item import Item
from app.schemas.college import (
    FlashCardData,
    FlashCardFeedbackRequest,
    FlashCardRegenerateRequest,
    FlashCardResponseWrapped,
)
from app.services.content import store
from app.services.generation.claude_client import ClaudeClient
from app.services.generation.usage import record_usage

logger = logging.getLogger(__name__)
router = APIRouter(tags=["flash-cards"])


async def _get_card_for_user(
    card_id: uuid.UUID,
    current_user,
    db: AsyncSession,
) -> FlashCard:
    card = await db.get(FlashCard, card_id)
    if card is None or card.user_id != current_user.id:
        raise not_found("CARD_NOT_FOUND", "Fiche introuvable")
    return card


@router.post("/flash-cards/{card_id}/feedback")
async def submit_feedback(
    card_id: uuid.UUID,
    body: FlashCardFeedbackRequest,
    current_user=Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
):
    card = await _get_card_for_user(card_id, current_user, db)
    card.user_feedback = body.feedback
    await db.commit()
    return {"data": {"id": str(card.id), "feedback": card.user_feedback}}


@router.delete("/flash-cards/{card_id}", status_code=204)
async def delete_card(
    card_id: uuid.UUID,
    current_user=Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
):
    card = await _get_card_for_user(card_id, current_user, db)
    await db.delete(card)
    await db.commit()


@router.post("/flash-cards/{card_id}/regenerate", response_model=FlashCardResponseWrapped)
@limiter.limit("10/hour")
async def regenerate_card(
    request: Request,
    card_id: uuid.UUID,
    body: FlashCardRegenerateRequest,
    current_user=Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
) -> FlashCardResponseWrapped:
    card = await _get_card_for_user(card_id, current_user, db)

    item = await db.get(Item, card.item_id)
    if item is None:
        raise unprocessable("ITEM_NOT_FOUND", "Item source introuvable")

    source_text = await store.get_item_text(db, item.text_hash) if item.text_hash else None
    if not source_text:
        raise conflict(
            "SOURCE_UNAVAILABLE",
            "Le texte source de cet item n'est pas disponible : réimporte le PDF pour pouvoir régénérer.",
        )

    claude = ClaudeClient()
    regen = await claude.regenerate_single_card(card, item, source_text, body.user_note)
    # Appel facturé compté même si la réponse est inutilisable ; APIError : usage à 0, rien.
    if regen.input_tokens or regen.output_tokens:
        await record_usage(
            database.async_session_factory,
            kind="regeneration",
            model=regen.model,
            input_tokens=regen.input_tokens,
            output_tokens=regen.output_tokens,
            user_id=current_user.id,
            college_id=card.college_id,
        )
    new_card_data = regen.card
    if new_card_data is None:
        raise AppError(503, "REGENERATION_FAILED", "Régénération échouée")

    # P1: card_type n'est PAS modifié — anti-pattern spec ("NE PAS modifier card_type")
    card.recto = new_card_data.recto
    card.verso = new_card_data.verso
    card.user_feedback = None
    card.generation_id = None  # plus la sortie d'origine de Claude : jamais partagée
    await db.commit()
    await db.refresh(card)

    # P5: réponse construite depuis card après refresh, pas depuis new_card_data
    return FlashCardResponseWrapped(
        data=FlashCardData(
            id=str(card.id),
            item_id=str(card.item_id),
            college_id=str(card.college_id),
            card_type=card.card_type,
            rang=card.rang,
            recto=card.recto,
            verso=card.verso,
            ocr_confidence_score=card.ocr_confidence_score,
            low_confidence=card.low_confidence,
            user_feedback=card.user_feedback,
        )
    )
