"""Enregistrement token APNs — FR23."""
from __future__ import annotations

import re

from fastapi import APIRouter, Depends
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
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
