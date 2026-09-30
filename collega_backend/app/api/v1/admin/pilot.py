"""Routes admin — pilotage de la beta : accueil, pastilles du menu, liste des collèges.

Toutes les routes sont protégées par HTTP Basic Auth."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Literal

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_admin_user
from app.schemas.admin_pilot import (
    AdminCollegesResponseWrapped,
    BadgesResponseWrapped,
    PilotResponseWrapped,
    RatedCardsResponseWrapped,
)
from app.services import admin_pilot

router = APIRouter()


@router.get("/pilot", response_model=PilotResponseWrapped)
async def get_pilot(_: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)) -> PilotResponseWrapped:
    return PilotResponseWrapped(data=await admin_pilot.pilot(db, datetime.now(UTC)))


@router.get("/badges", response_model=BadgesResponseWrapped)
async def get_badges(_: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)) -> BadgesResponseWrapped:
    return BadgesResponseWrapped(data=await admin_pilot.badges(db, datetime.now(UTC)))


@router.post("/badges/quality-seen", status_code=204)
async def post_quality_seen(_: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)) -> Response:
    await admin_pilot.mark_quality_seen(db, datetime.now(UTC))
    return Response(status_code=204)


@router.get("/colleges", response_model=AdminCollegesResponseWrapped)
async def get_colleges(
    _: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)
) -> AdminCollegesResponseWrapped:
    return AdminCollegesResponseWrapped(data=await admin_pilot.list_colleges(db))


@router.get("/rated-cards", response_model=RatedCardsResponseWrapped)
async def get_rated_cards(
    feedback: Literal["positive", "negative"] | None = None,
    limit: int = Query(200, ge=1, le=1000),
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> RatedCardsResponseWrapped:
    return RatedCardsResponseWrapped(data=await admin_pilot.rated_cards(db, feedback, limit))
