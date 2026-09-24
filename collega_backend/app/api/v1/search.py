"""FR36–37 — Recherche full-text sur fiches utilisateur via GIN index PostgreSQL."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.limiter import limiter
from app.core.limiter import user_id_key as _user_id_key  # clé par utilisatrice (Story 7.2 AC #3)
from app.deps import get_current_user, require_subscription
from app.models.user import User
from app.services.search.full_text_search import search_flash_cards

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/search")
@limiter.limit("30/minute", key_func=_user_id_key)
async def search(
    request: Request,
    q: str = Query(..., min_length=2, max_length=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    _: None = Depends(require_subscription),
):
    results = await search_flash_cards(db, current_user.id, q)
    # Jamais le terme cherché dans les logs (chantier 2 § 6).
    logger.info("Search user=%s results=%d", current_user.id, len(results))
    return {"data": results}
