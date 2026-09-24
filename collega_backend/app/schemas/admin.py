"""Schemas Pydantic pour les routes admin — pipeline OCR Phase 0 + Story 1.4."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, EmailStr, Field

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


# ── Story 1.5 — Pertinence stats (avis flash_cards.user_feedback) ─────────────


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
    monthly_reloads_max: int


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
    reload_count_max: int | None = Field(default=None, ge=0)
    monthly_reloads_max: int | None = Field(default=None, ge=0)


class ConfigResponseWrapped(BaseModel):
    data: ConfigData


# ── Story 7.6 — Création utilisateur admin (hard-blocker onboarding) ──────────


class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    is_beta: bool = False


class CreateUserResponseWrapped(BaseModel):
    data: UserBetaData


# ── Story 7.6 — Reset quota mensuel ──────────────────────────────────────────


class ResetQuotaResponseWrapped(BaseModel):
    data: UserBetaData


# ── Story 7.6 — Détail utilisateur (collèges + jobs + quota) ──────────────────


class UserCollegeSummary(BaseModel):
    college_id: str
    college_ref_id: int
    status: str
    reload_count: int
    reload_count_max: int


class UserJobSummary(BaseModel):
    job_id: str
    college_id: str
    status: str
    card_count: int
    error_message: str | None
    created_at: str | None


class UserDetailData(BaseModel):
    user_id: str
    email: str
    is_beta: bool
    is_subscribed: bool
    monthly_reloads: int
    monthly_reloads_max: int
    monthly_reloads_reset_at: str | None
    created_at: str | None
    colleges: list[UserCollegeSummary]
    jobs: list[UserJobSummary]


class UserDetailResponseWrapped(BaseModel):
    data: UserDetailData


# ── Story 7.6 — Overview KPI (point d'entrée console) ─────────────────────────


class OverviewData(BaseModel):
    users_total: int
    jobs_by_status: dict[str, int]
    jobs_failed: int


class OverviewResponseWrapped(BaseModel):
    data: OverviewData


# ── Story 7.7 — Suivi & contrôle imports (timeline / détail / stop) ───────────


class JobEventData(BaseModel):
    event_type: str
    message: str | None
    page: int | None
    total: int | None
    created_at: str | None


class JobDetailData(BaseModel):
    job_id: str
    college_id: str
    user_id: str
    status: str
    arq_job_id: str | None
    pdf_hash: str | None
    hash_shared: bool
    card_count: int
    error_message: str | None
    created_at: str | None
    updated_at: str | None
    ocr_page_progress: int
    total_pages: int | None
    college_status: str
    items: list[ItemOcrData]
    timeline: list[JobEventData]
    # Story 7.8 — coût/import (additif). NULL = job non mesuré (antérieur migration 014).
    input_tokens: int | None = None
    output_tokens: int | None = None
    cost_eur: float = 0.0


class JobDetailResponseWrapped(BaseModel):
    data: JobDetailData


class StopJobData(BaseModel):
    job_id: str
    status: str
    error_message: str | None
    # True si l'abort ARQ a été confirmé ; False si l'arq_job_id était absent ou
    # si l'abort n'a pas abouti (job déjà terminé, Redis injoignable, flag worker
    # absent). Le statut DB est forcé à "failed" indépendamment de cette valeur.
    aborted: bool = False


class StopJobResponseWrapped(BaseModel):
    data: StopJobData


# ── Story 7.8 — Qualité : inspection fiches générées ──────────────────────────


class AdminFlashCardData(BaseModel):
    card_id: str
    item_number: int | None
    card_type: str
    rang: str
    recto: str
    verso: str
    ocr_confidence_score: float
    low_confidence: bool


class AdminCardsResponseWrapped(BaseModel):
    data: list[AdminFlashCardData]
    total: int


# ── Story 7.8 — Qualité : avis de l'utilisatrice joint au contenu fiche ───────


class AdminFeedbackData(BaseModel):
    flash_card_id: str
    item_number: int
    user_email: str
    feedback: Literal["positive", "negative"]
    is_pertinent: bool
    recto: str
    verso: str
    card_type: str
    rang: str


class AdminFeedbackResponseWrapped(BaseModel):
    data: list[AdminFeedbackData]
    total: int


# ── Story 7.8 — Coût : agrégat usage tokens + € (global / par user) ───────────


class UsageByUserData(BaseModel):
    user_id: str
    email: str
    input_tokens: int
    output_tokens: int
    cost_eur: float


class UsageData(BaseModel):
    input_tokens: int
    output_tokens: int
    cost_eur: float
    by_user: list[UsageByUserData]


class UsageResponseWrapped(BaseModel):
    data: UsageData
