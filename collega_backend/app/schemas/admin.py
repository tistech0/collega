"""Schemas Pydantic pour les routes admin — pipeline OCR Phase 0."""
from __future__ import annotations

import uuid

from pydantic import BaseModel


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
