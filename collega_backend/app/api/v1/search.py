"""FR36–37 — Recherche full-text sur fiches utilisateur via GIN index PostgreSQL."""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.limiter import limiter
from app.deps import get_current_user, require_subscription
from app.models.user import User
from app.services.search.full_text_search import search_flash_cards

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/search")
@limiter.limit("30/minute")
async def search(
    request: Request,
    q: str = Query(..., min_length=2, max_length=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    _: None = Depends(require_subscription),
):
    logger.info("Search q=%r user=%s", q, current_user.id)
    results = await search_flash_cards(db, current_user.id, q)
    return {"data": results}
