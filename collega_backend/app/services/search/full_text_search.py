"""Service de recherche full-text via PostgreSQL GIN index."""

from __future__ import annotations

import logging
import re
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

MAX_RESULTS = 20
EXCERPT_MAX_CHARS = 220

_MARK_RE = re.compile(r"<mark>(.*?)</mark>", re.DOTALL)
# Fin de phrase, retour à la ligne, puce : l'extrait ne déborde jamais sur la voisine.
# « ; » ne coupe pas (énumérations médicales) ; « cf. », « p. ex. », « etc. »,
# initiales (« M. ») non plus.
_SENTENCE_SPLIT_RE = re.compile(
    r"(?<!\bcf\.)(?<!\bex\.)(?<!\betc\.)(?<!\benv\.)(?<!\bvs\.)(?<!\b\w\.)(?<=[.!?])\s+|\n+|^\s*[-•*]\s+",
    re.MULTILINE | re.IGNORECASE,
)


def build_excerpt(text: str, headline: str, max_chars: int = EXCERPT_MAX_CHARS) -> str:
    """Phrase entière de [text] contenant un terme surligné par ts_headline, termes surlignés.

    ts_headline découpe au nombre de mots (souvent le mot seul) : on garde ses
    termes surlignés (déjà sous leur forme dans le texte) et on rend la phrase
    qui les contient. Phrase trop longue : fenêtre autour du terme, avec « … ».
    Sans terme retrouvé, le headline est rendu tel quel.
    """
    terms = {m.strip() for m in _MARK_RE.findall(headline) if m.strip()}
    if not terms:
        return headline
    alternation = "|".join(re.escape(t) for t in sorted(terms, key=len, reverse=True))
    term_re = re.compile(rf"(?<!\w)(?:{alternation})(?!\w)", re.IGNORECASE)

    for raw in _SENTENCE_SPLIT_RE.split(text):
        sentence = " ".join((raw or "").split())
        match = term_re.search(sentence)
        if not match:
            continue
        prefix = suffix = ""
        if len(sentence) > max_chars:
            start = max(0, match.start() - (max_chars - (match.end() - match.start())) // 2)
            end = min(len(sentence), start + max_chars)
            start = max(0, end - max_chars)
            # Coupe aux espaces : jamais un mot tronqué.
            if start > 0:
                space = sentence.find(" ", start)
                start = space + 1 if 0 <= space < match.start() else start
                prefix = "…"
            if end < len(sentence):
                space = sentence.rfind(" ", match.end(), end)
                end = space if space > 0 else end
                suffix = "…"
            sentence = sentence[start:end].strip()
        return prefix + term_re.sub(lambda m: f"<mark>{m.group(0)}</mark>", sentence) + suffix
    return headline


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
            fc.recto,
            fc.verso,
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

    results = []
    for r in sorted_rows[:MAX_RESULTS]:
        row = dict(r)
        # La réponse (verso) d'abord : elle porte l'information, la question la répète.
        recto = row.pop("recto", "") or ""
        text_ = f"{row.pop('verso', '') or ''}\n{recto}"
        row["excerpt"] = build_excerpt(text_, row.get("excerpt") or "")
        results.append(row)
    return results
