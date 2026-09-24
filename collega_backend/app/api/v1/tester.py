"""Routes testeur Phase 0 — navigation fiches et feedback (Story 1.5).

Toutes les routes sont protégées par HTTP Basic Auth (credentials distincts de l'admin).
"""

from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_tester_user
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.tester_feedback import TesterFeedback
from app.schemas.tester import (
    CollegeItemsData,
    CollegeItemsResponse,
    CollegesListResponse,
    CollegeSummaryData,
    CollegeSummaryResponse,
    CollegeTesterData,
    FeedbackData,
    FeedbackRequest,
    FeedbackResponseData,
    FeedbackResponseWrapped,
    FlashCardTesterData,
    ItemSummaryData,
    ItemTesterData,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["tester"])


@router.get("/colleges", response_model=CollegesListResponse)
async def list_colleges(
    tester_id: str = Depends(get_tester_user),
    db: AsyncSession = Depends(get_db),
) -> CollegesListResponse:
    """Liste les collèges ayant au moins un job generation_complete."""
    college_ids_result = await db.execute(
        select(GenerationJob.college_id).where(GenerationJob.status == "generation_complete").distinct()
    )
    college_ids = college_ids_result.scalars().all()

    if not college_ids:
        return CollegesListResponse(data=[], total=0)

    colleges_result = await db.execute(select(College).where(College.id.in_(college_ids)))
    colleges = colleges_result.scalars().all()

    data = []
    for college in colleges:
        card_count = (
            await db.execute(select(func.count(FlashCard.id)).where(FlashCard.college_id == college.id))
        ).scalar_one()
        feedback_count = (
            await db.execute(select(func.count(TesterFeedback.id)).where(TesterFeedback.college_id == college.id))
        ).scalar_one()
        data.append(
            CollegeTesterData(
                college_id=str(college.id),
                college_ref_id=college.college_ref_id,
                card_count=card_count,
                feedback_count=feedback_count,
            )
        )

    return CollegesListResponse(data=data, total=len(data))


@router.get("/colleges/{college_id}/items", response_model=CollegeItemsResponse)
async def get_college_items(
    college_id: uuid.UUID,
    tester_id: str = Depends(get_tester_user),
    db: AsyncSession = Depends(get_db),
) -> CollegeItemsResponse:
    """Retourne tous les items d'un collège avec leurs fiches et le feedback existant."""
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    items_result = await db.execute(select(Item).where(Item.college_id == college_id).order_by(Item.item_number))
    items = items_result.scalars().all()

    items_data = []
    for item in items:
        cards_result = await db.execute(
            select(FlashCard, TesterFeedback)
            .outerjoin(
                TesterFeedback,
                (TesterFeedback.flash_card_id == FlashCard.id) & (TesterFeedback.tester_id == tester_id),
            )
            .where(FlashCard.item_id == item.id)
            .order_by(FlashCard.rang, FlashCard.created_at)
        )
        cards_rows = cards_result.all()

        cards_data = []
        for card, feedback in cards_rows:
            fb_data = None
            if feedback is not None:
                fb_data = FeedbackData(
                    is_pertinent=feedback.is_pertinent,
                    tester_id=feedback.tester_id,
                    created_at=feedback.created_at,
                )
            cards_data.append(
                FlashCardTesterData(
                    card_id=str(card.id),
                    card_type=card.card_type,
                    rang=card.rang,
                    recto=card.recto,
                    verso=card.verso,
                    low_confidence=card.low_confidence,
                    ocr_confidence_score=card.ocr_confidence_score,
                    feedback=fb_data,
                )
            )

        items_data.append(
            ItemTesterData(
                item_id=str(item.id),
                item_number=item.item_number,
                rang=item.rang,
                chapter_title=item.chapter_title,
                flash_cards=cards_data,
            )
        )

    return CollegeItemsResponse(data=CollegeItemsData(college_id=str(college_id), items=items_data))


@router.post("/flash-cards/{card_id}/feedback", response_model=FeedbackResponseWrapped)
async def submit_feedback(
    card_id: uuid.UUID,
    body: FeedbackRequest,
    tester_id: str = Depends(get_tester_user),
    db: AsyncSession = Depends(get_db),
) -> FeedbackResponseWrapped:
    """Enregistre ou met à jour le feedback d'une fiche (UPSERT par card_id + tester_id)."""
    card = await db.get(FlashCard, card_id)
    if card is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "CARD_NOT_FOUND", "message": f"FlashCard {card_id} not found"},
        )

    existing_result = await db.execute(
        select(TesterFeedback)
        .where(TesterFeedback.flash_card_id == card_id)
        .where(TesterFeedback.tester_id == tester_id)
    )
    feedback = existing_result.scalar_one_or_none()

    if feedback is None:
        feedback = TesterFeedback(
            flash_card_id=card_id,
            college_id=card.college_id,
            tester_id=tester_id,
            is_pertinent=body.is_pertinent,
        )
        db.add(feedback)
    else:
        feedback.is_pertinent = body.is_pertinent

    await db.commit()
    await db.refresh(feedback)

    return FeedbackResponseWrapped(
        data=FeedbackResponseData(
            feedback_id=str(feedback.id),
            card_id=str(feedback.flash_card_id),
            is_pertinent=feedback.is_pertinent,
            tester_id=feedback.tester_id,
            created_at=feedback.created_at,
        )
    )


@router.get("/colleges/{college_id}/summary", response_model=CollegeSummaryResponse)
async def get_college_summary(
    college_id: uuid.UUID,
    tester_id: str = Depends(get_tester_user),
    db: AsyncSession = Depends(get_db),
) -> CollegeSummaryResponse:
    """Résumé des feedbacks par item pour un collège."""
    college = await db.get(College, college_id)
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"},
        )

    items_result = await db.execute(select(Item).where(Item.college_id == college_id).order_by(Item.item_number))
    items = items_result.scalars().all()

    items_data = []
    for item in items:
        card_ids = (await db.execute(select(FlashCard.id).where(FlashCard.item_id == item.id))).scalars().all()
        total = len(card_ids)

        pertinent = 0
        not_pertinent = 0
        if card_ids:
            feedbacks = (
                (
                    await db.execute(
                        select(TesterFeedback)
                        .where(TesterFeedback.flash_card_id.in_(card_ids))
                        .where(TesterFeedback.tester_id == tester_id)
                    )
                )
                .scalars()
                .all()
            )
            pertinent = sum(1 for f in feedbacks if f.is_pertinent)
            not_pertinent = sum(1 for f in feedbacks if not f.is_pertinent)

        items_data.append(
            ItemSummaryData(
                item_id=str(item.id),
                item_number=item.item_number,
                rang=item.rang,
                total_cards=total,
                pertinent_count=pertinent,
                not_pertinent_count=not_pertinent,
                pending_count=total - (pertinent + not_pertinent),
            )
        )

    return CollegeSummaryResponse(data=CollegeSummaryData(college_id=str(college_id), items=items_data))
