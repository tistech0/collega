import uuid
from datetime import datetime

from pydantic import BaseModel


class FlashCardCreate(BaseModel):
    item_id: uuid.UUID
    college_id: uuid.UUID
    user_id: uuid.UUID
    card_type: str
    rang: str
    recto: str
    verso: str
    ocr_confidence_score: float = 0.0
    low_confidence: bool = False


class FlashCardRead(BaseModel):
    id: uuid.UUID
    item_id: uuid.UUID
    college_id: uuid.UUID
    user_id: uuid.UUID
    card_type: str
    rang: str
    recto: str
    verso: str
    ocr_confidence_score: float
    low_confidence: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
