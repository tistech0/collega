"""Schemas Pydantic pour les routes testeur — interface web Phase 0 (Story 1.5)."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class CollegeTesterData(BaseModel):
    college_id: str
    college_ref_id: int
    card_count: int
    feedback_count: int


class CollegesListResponse(BaseModel):
    data: list[CollegeTesterData]
    total: int


class FeedbackData(BaseModel):
    is_pertinent: bool
    tester_id: str
    created_at: datetime


class FlashCardTesterData(BaseModel):
    card_id: str
    card_type: str
    rang: str
    recto: str
    verso: str
    low_confidence: bool
    ocr_confidence_score: float
    feedback: FeedbackData | None


class ItemTesterData(BaseModel):
    item_id: str
    item_number: int
    rang: str
    chapter_title: str | None
    flash_cards: list[FlashCardTesterData]


class CollegeItemsData(BaseModel):
    college_id: str
    items: list[ItemTesterData]


class CollegeItemsResponse(BaseModel):
    data: CollegeItemsData


class FeedbackRequest(BaseModel):
    is_pertinent: bool


class FeedbackResponseData(BaseModel):
    feedback_id: str
    card_id: str
    is_pertinent: bool
    tester_id: str
    created_at: datetime


class FeedbackResponseWrapped(BaseModel):
    data: FeedbackResponseData


class ItemSummaryData(BaseModel):
    item_id: str
    item_number: int
    rang: str
    total_cards: int
    pertinent_count: int
    not_pertinent_count: int
    pending_count: int


class CollegeSummaryData(BaseModel):
    college_id: str
    items: list[ItemSummaryData]


class CollegeSummaryResponse(BaseModel):
    data: CollegeSummaryData
