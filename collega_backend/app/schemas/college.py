from typing import Literal

from pydantic import BaseModel, Field


class UserCollegeData(BaseModel):
    college_ref_id: int
    college_id: str
    status: str
    card_count_a: int = 0
    card_count_b: int = 0
    card_count_c: int = 0


class CollegesListResponseWrapped(BaseModel):
    data: list[UserCollegeData]
    total: int


class ImportCollegeResponseData(BaseModel):
    college_id: str
    job_id: str
    status: str


class ImportCollegeResponseWrapped(BaseModel):
    data: ImportCollegeResponseData


# ── Story 7.11 — upload par morceaux ──────────────────────────────────────────


class UploadInitRequest(BaseModel):
    size_bytes: int = Field(..., gt=0)


class UploadInitData(BaseModel):
    upload_id: str
    part_size: int
    parts_total: int
    expires_at: str


class UploadInitResponseWrapped(BaseModel):
    data: UploadInitData


class UploadStatusData(BaseModel):
    received: list[int]
    parts_total: int
    part_size: int
    size_bytes: int
    expires_at: str


class UploadStatusResponseWrapped(BaseModel):
    data: UploadStatusData


class CollegeStatusData(BaseModel):
    college_id: str
    ref_id: int
    status: str
    ocr_page_progress: int
    total_pages: int | None
    job_id: str | None
    # Chantier 1 : résumé du dernier réimport réussi, et échec d'un réimport (contenu intact).
    summary: dict | None = None
    reimport: bool = False


class CollegeStatusResponseWrapped(BaseModel):
    data: CollegeStatusData


class ItemSummaryData(BaseModel):
    id: str
    item_number: int
    rang: str
    chapter_title: str | None
    ocr_confidence_score: float
    low_confidence: bool
    card_count_a: int
    card_count_b: int
    card_count_c: int


class ItemsListResponseWrapped(BaseModel):
    data: list[ItemSummaryData]
    total: int


class FlashCardData(BaseModel):
    id: str
    item_id: str
    college_id: str
    card_type: str
    rang: str
    recto: str
    verso: str
    ocr_confidence_score: float
    low_confidence: bool
    user_feedback: str | None = None


class CardsListResponseWrapped(BaseModel):
    data: list[FlashCardData]
    total: int


class FlashCardFeedbackRequest(BaseModel):
    feedback: Literal["positive", "negative"]


class FlashCardRegenerateRequest(BaseModel):
    user_note: str | None = None


class FlashCardResponseWrapped(BaseModel):
    data: FlashCardData


class ReloadLimitsData(BaseModel):
    college_reload_count: int
    college_reload_max: int
    monthly_reloads: int
    monthly_max: int
    monthly_reset_at: str  # ISO 8601 UTC


class ReloadLimitsResponseWrapped(BaseModel):
    data: ReloadLimitsData
