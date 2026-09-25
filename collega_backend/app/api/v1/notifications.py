"""Enregistrement token APNs — FR23."""

from __future__ import annotations

import re

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.limiter import limiter
from app.deps import get_current_user

router = APIRouter(tags=["notifications"])


class ApnsTokenRequest(BaseModel):
    token: str

    @field_validator("token")
    @classmethod
    def validate_token_format(cls, v: str) -> str:
        if not re.match(r"^[0-9a-fA-F]{64,200}$", v):
            raise ValueError("Format APNs token invalide (attendu : 64-200 caractères hexadécimaux)")
        return v


@router.post("/notifications/apns-token")
async def register_apns_token(
    body: ApnsTokenRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.apns_token = body.token
    await db.commit()
    return {"data": {"registered": True}}


class ReminderRequest(BaseModel):
    hour_utc: int

    @field_validator("hour_utc")
    @classmethod
    def validate_hour(cls, v: int) -> int:
        if not 0 <= v <= 23:
            raise ValueError("hour_utc doit être entre 0 et 23")
        return v


@router.post("/notifications/reminder")
@limiter.limit("10/minute")
async def set_reminder(
    request: Request,
    body: ReminderRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.reminder_hour_utc = body.hour_utc
    await db.commit()
    return {"data": {"reminder_enabled": True, "hour_utc": body.hour_utc}}


@router.delete("/notifications/reminder")
@limiter.limit("10/minute")
async def clear_reminder(
    request: Request,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.reminder_hour_utc = None
    await db.commit()
    return {"data": {"reminder_enabled": False}}
