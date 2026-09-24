"""Routes collèges utilisateur — items et fiches d'un collège."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_current_user
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.item import Item
from app.models.user import User
from app.schemas.college import (
    CardsListResponseWrapped,
    FlashCardData,
    ItemsListResponseWrapped,
    ItemSummaryData,
)

router = APIRouter()


@router.get("/colleges/{college_id}/items", response_model=ItemsListResponseWrapped)
async def list_college_items(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ItemsListResponseWrapped:
    """Retourne tous les items d'un collège dont la génération est terminée."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "College not found"},
        )
    if college.status != "generation_complete":
        raise HTTPException(
            status_code=409,
            detail={"code": "GENERATION_NOT_COMPLETE", "message": "Generation not yet complete"},
        )

    items_result = await db.execute(select(Item).where(Item.college_id == college_id).order_by(Item.item_number))
    items = items_result.scalars().all()
    if not items:
        return ItemsListResponseWrapped(data=[], total=0)

    item_ids = [i.id for i in items]
    counts_result = await db.execute(
        select(FlashCard.item_id, FlashCard.rang, func.count(FlashCard.id))
        .where(FlashCard.item_id.in_(item_ids))
        .group_by(FlashCard.item_id, FlashCard.rang)
    )
    counts: dict[uuid.UUID, dict[str, int]] = {}
    for item_id_row, rang, count in counts_result.all():
        counts.setdefault(item_id_row, {})[rang] = count

    data = [
        ItemSummaryData(
            id=str(item.id),
            item_number=item.item_number,
            rang=item.rang,
            chapter_title=item.chapter_title,
            ocr_confidence_score=item.ocr_confidence_score,
            low_confidence=item.low_confidence,
            card_count_a=counts.get(item.id, {}).get("A", 0),
            card_count_b=counts.get(item.id, {}).get("B", 0),
            card_count_c=counts.get(item.id, {}).get("C", 0),
        )
        for item in items
    ]
    return ItemsListResponseWrapped(data=data, total=len(data))


@router.get("/colleges/{college_id}/cards", response_model=CardsListResponseWrapped)
async def list_college_cards(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CardsListResponseWrapped:
    """Toutes les flashcards d'un collège (story 8.3).

    L'app les synchronise en local d'un seul appel : la session du jour mêle les
    collèges et doit fonctionner hors-ligne, sans attendre l'ouverture de chaque item.
    Triées item, rang puis card_type pour un ordre stable.
    """
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "College not found"},
        )
    if college.status != "generation_complete":
        raise HTTPException(
            status_code=409,
            detail={"code": "GENERATION_NOT_COMPLETE", "message": "Generation not yet complete"},
        )

    cards_result = await db.execute(
        select(FlashCard)
        .where(FlashCard.college_id == college_id)
        .order_by(FlashCard.item_id, FlashCard.rang, FlashCard.card_type)
    )
    data = [
        FlashCardData(
            id=str(c.id),
            item_id=str(c.item_id),
            college_id=str(c.college_id),
            card_type=c.card_type,
            rang=c.rang,
            recto=c.recto,
            verso=c.verso,
            ocr_confidence_score=c.ocr_confidence_score,
            low_confidence=c.low_confidence,
            user_feedback=c.user_feedback,
        )
        for c in cards_result.scalars().all()
    ]
    return CardsListResponseWrapped(data=data, total=len(data))


@router.get("/colleges/{college_id}/items/{item_id}/cards", response_model=CardsListResponseWrapped)
async def list_item_cards(
    college_id: uuid.UUID,
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CardsListResponseWrapped:
    """Retourne toutes les flashcards d'un item, triées rang ASC puis card_type ASC."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "College not found"},
        )
    if college.status != "generation_complete":
        raise HTTPException(
            status_code=409,
            detail={"code": "GENERATION_NOT_COMPLETE", "message": "Generation not yet complete"},
        )

    item = await db.get(Item, item_id)
    if item is None or item.college_id != college_id:
        raise HTTPException(
            status_code=404,
            detail={"code": "ITEM_NOT_FOUND", "message": "Item not found"},
        )

    cards_result = await db.execute(
        select(FlashCard).where(FlashCard.item_id == item_id).order_by(FlashCard.rang, FlashCard.card_type)
    )
    cards = cards_result.scalars().all()
    data = [
        FlashCardData(
            id=str(c.id),
            item_id=str(c.item_id),
            college_id=str(c.college_id),
            card_type=c.card_type,
            rang=c.rang,
            recto=c.recto,
            verso=c.verso,
            ocr_confidence_score=c.ocr_confidence_score,
            low_confidence=c.low_confidence,
            user_feedback=c.user_feedback,
        )
        for c in cards
    ]
    return CardsListResponseWrapped(data=data, total=len(data))
