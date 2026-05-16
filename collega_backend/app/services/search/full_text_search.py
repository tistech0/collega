"""Service de recherche full-text via PostgreSQL GIN index."""
from __future__ import annotations

import logging
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

MAX_RESULTS = 20


async def search_flash_cards(
    db: AsyncSession,
    user_id: uuid.UUID,
    query: str,
) -> list[dict]:
    """
    Recherche full-text sur flash_cards (recto + verso) via GIN index.
    Retourne les items distincts triés par pertinence, avec extrait contextuel.
    """
    sql = text("""
        SELECT DISTINCT ON (fc.item_id)
            fc.item_id::text,
            i.item_number,
            i.rang,
            i.chapter_title,
            c.id::text AS college_id,
            c.college_ref_id,
            ts_headline(
                'french',
                coalesce(fc.recto, '') || ' ' || coalesce(fc.verso, ''),
                plainto_tsquery('french', :query),
                'MaxWords=20, MinWords=5, StartSel=<mark>, StopSel=</mark>, HighlightAll=false'
            ) AS excerpt,
            ts_rank(
                to_tsvector('french', coalesce(fc.recto, '') || ' ' || coalesce(fc.verso, '')),
                plainto_tsquery('french', :query)
            ) AS rank
        FROM flash_cards fc
        JOIN items i ON fc.item_id = i.id
        JOIN colleges c ON fc.college_id = c.id
        WHERE fc.user_id = :user_id
          AND to_tsvector('french', coalesce(fc.recto, '') || ' ' || coalesce(fc.verso, ''))
              @@ plainto_tsquery('french', :query)
        ORDER BY fc.item_id, rank DESC
    """)

    result = await db.execute(sql, {"query": query, "user_id": str(user_id)})
    rows = result.mappings().all()

    # Re-trier par rank décroissant (DISTINCT ON trie par item_id en premier)
    sorted_rows = sorted(rows, key=lambda r: r["rank"], reverse=True)

    return [dict(r) for r in sorted_rows[:MAX_RESULTS]]
