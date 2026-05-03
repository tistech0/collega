"""Schemas Pydantic pour les routes admin — pipeline OCR Phase 0 + Story 1.4."""
from __future__ import annotations

from pydantic import BaseModel, Field


# ── College creation ─────────────────────────────────────────────────────────

class CreateCollegeRequest(BaseModel):
    user_id: str
    college_ref_id: int = Field(..., ge=1)


class CreateCollegeData(BaseModel):
    college_id: str
    user_id: str
    college_ref_id: int


class CreateCollegeResponseWrapped(BaseModel):
    data: CreateCollegeData


# ── Story 1.2 — existant ──────────────────────────────────────────────────────

class ProcessCollegeResponse(BaseModel):
    job_id: str
    status: str


class CollegeStatusData(BaseModel):
    status: str
    ocr_page_progress: int
    total_pages: int | None
    job_id: str | None


class ProcessCollegeResponseWrapped(BaseModel):
    data: ProcessCollegeResponse


class CollegeStatusResponseWrapped(BaseModel):
    data: CollegeStatusData


# ── Story 1.4 — Queue dashboard ───────────────────────────────────────────────

class QueueJobData(BaseModel):
    job_id: str
    college_id: str
    status: str
    college_ocr_page_progress: int
    college_total_pages: int | None
    card_count: int
    elapsed_seconds: float
    error_message: str | None


class QueueResponse(BaseModel):
    data: list[QueueJobData]
    total: int


# ── Story 1.4 — Stats collège ─────────────────────────────────────────────────

class ItemOcrData(BaseModel):
    item_number: int
    ocr_confidence_score: float
    low_confidence: bool


# ── Story 1.5 — Pertinence stats (feedback testeur) ───────────────────────────

class PertinenceByRang(BaseModel):
    pertinent: int
    not_pertinent: int


class PertinenceStats(BaseModel):
    global_pertinent: int
    global_not_pertinent: int
    total_evaluated: int
    by_rang: dict[str, PertinenceByRang]


# ─────────────────────────────────────────────────────────────────────────────

class CollegeStatsData(BaseModel):
    card_count_by_rang: dict[str, int]
    avg_ocr_confidence: float | None
    items_ocr_confidence: list[ItemOcrData]
    hash_shared: bool
    pertinence_stats: PertinenceStats | None = None


class CollegeStatsResponseWrapped(BaseModel):
    data: CollegeStatsData


# ── Story 1.4 — Gestion beta ──────────────────────────────────────────────────

class UserBetaData(BaseModel):
    user_id: str
    email: str
    is_beta: bool
    is_subscribed: bool
    monthly_reloads: int


class UsersListResponseWrapped(BaseModel):
    data: list[UserBetaData]
    total: int


class BetaUpdateRequest(BaseModel):
    is_beta: bool


class BetaUpdateResponseWrapped(BaseModel):
    data: UserBetaData


# ── Story 1.4 — Configuration anti-spam ──────────────────────────────────────

class ConfigData(BaseModel):
    reload_count_max: int
    monthly_reloads_max: int


class ConfigUpdateRequest(BaseModel):
    reload_count_max: int | None = Field(default=None, ge=1)
    monthly_reloads_max: int | None = Field(default=None, ge=1)


class ConfigResponseWrapped(BaseModel):
    data: ConfigData
