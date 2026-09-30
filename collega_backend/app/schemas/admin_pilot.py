"""Schemas Pydantic — console de pilotage de la beta (accueil, pastilles, collèges)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel


class Kpi(BaseModel):
    value: float
    previous: float


class TesterRow(BaseModel):
    user_id: str
    email: str
    first_name: str | None
    is_beta: bool
    created_at: str
    last_seen_at: str | None
    status: str  # active | inactive | never_seen
    streak: int
    cards_7d: int
    college_count: int


class WatchJob(BaseModel):
    job_id: str
    college_id: str
    college_name: str
    user_email: str | None
    status: str
    kind: str  # failed | stalled
    message: str | None
    updated_at: str


class WatchFeedback(BaseModel):
    college_id: str
    college_name: str
    negative_count: int


class RunningJob(BaseModel):
    job_id: str
    college_name: str
    user_email: str | None
    status: str
    progress: float  # 0..1


class PilotData(BaseModel):
    testers_total: int
    active_7d: Kpi
    cards_7d: Kpi
    failed_imports_7d: Kpi
    cost_30d_eur: Kpi
    testers: list[TesterRow]
    watch_jobs: list[WatchJob]
    watch_feedback: list[WatchFeedback]
    running_jobs: list[RunningJob]


class PilotResponseWrapped(BaseModel):
    data: PilotData


class BadgesData(BaseModel):
    testers: int
    imports: int
    quality: int


class BadgesResponseWrapped(BaseModel):
    data: BadgesData


class AdminCollegeRow(BaseModel):
    college_id: str
    college_ref_id: int
    college_name: str
    user_email: str | None
    status: str
    card_count: int
    negative_count: int
    created_at: str


class AdminCollegesResponseWrapped(BaseModel):
    data: list[AdminCollegeRow]


class RatedCard(BaseModel):
    card_id: str
    college_id: str
    college_name: str
    user_email: str | None
    item_number: int | None
    card_type: str
    rang: str
    recto: str
    verso: str
    feedback: Literal["positive", "negative"]
    # Dernière mise à jour de la fiche : l'avis est la seule modification courante.
    rated_at: str


class RatedCardsData(BaseModel):
    positive: int
    negative: int
    cards: list[RatedCard]


class RatedCardsResponseWrapped(BaseModel):
    data: RatedCardsData
