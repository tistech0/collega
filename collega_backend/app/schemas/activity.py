from datetime import date

from pydantic import BaseModel, Field


class ActivityDayRequest(BaseModel):
    cards_reviewed: int = Field(..., ge=0, le=5000)
    session_completed: bool
    streak: int = Field(..., ge=0, le=3650)


class ActivityDayData(ActivityDayRequest):
    day: date


class ActivityDayResponseWrapped(BaseModel):
    data: ActivityDayData
