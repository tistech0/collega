"""Schemas Pydantic pour les items OCR."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel

RangType = Literal["A", "B", "C"]


class ItemCreate(BaseModel):
    college_id: uuid.UUID
    item_number: int
    rang: RangType
    chapter_title: str | None = None
    ocr_text: str | None = None
    ocr_confidence_score: float = 0.0
    low_confidence: bool = False
    start_page: int | None = None
    end_page: int | None = None


class ItemRead(BaseModel):
    id: uuid.UUID
    college_id: uuid.UUID
    item_number: int
    rang: RangType
    chapter_title: str | None
    ocr_confidence_score: float
    low_confidence: bool
    start_page: int | None
    end_page: int | None
    created_at: datetime

    model_config = {"from_attributes": True}
