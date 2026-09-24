"""Exporte les pages OCR en service de chaque collège en fixtures JSON (chantier 4).

Contenu sous droits : les fichiers vont dans tests/fixtures/private/ (git-ignoré).
Lecture seule. Sur le NAS, sans déployer le script :

    docker exec -i collega-api-1 python - --out /tmp/collega_pdfs/fixtures < scripts/export_page_fixtures.py

Un fichier par collège : college_<ref_id>.json =
    {"college_ref_id", "items": [{"item_number", "rang", "start_page", "end_page", "chapter_title"}],
     "pages": [{"page_number", "text", "tables", "confidence", "method"}]}
"""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path

from sqlalchemy import text

from app.core.database import async_session_factory

_PAGES = text(
    """
    SELECT cp.page_number, p.text, p.tables_json, p.confidence, p.method
    FROM college_pages cp JOIN ocr_pages p ON p.hash = cp.page_hash
    WHERE cp.college_id = :college_id ORDER BY cp.page_number
    """
)
_ITEMS = text(
    """
    SELECT item_number, rang, start_page, end_page, chapter_title
    FROM items WHERE college_id = :college_id ORDER BY item_number
    """
)


async def export(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    async with async_session_factory() as db:
        colleges = (await db.execute(text("SELECT id, college_ref_id FROM colleges ORDER BY college_ref_id"))).all()
        for college_id, ref_id in colleges:
            pages = (await db.execute(_PAGES, {"college_id": college_id})).all()
            if not pages:
                continue
            items = (await db.execute(_ITEMS, {"college_id": college_id})).mappings().all()
            data = {
                "college_ref_id": ref_id,
                "items": [dict(i) for i in items],
                "pages": [
                    {"page_number": n, "text": t, "tables": json.loads(tj), "confidence": c, "method": m}
                    for n, t, tj, c, m in pages
                ],
            }
            path = out / f"college_{ref_id}.json"
            path.write_text(json.dumps(data, ensure_ascii=False))
            print(f"{path} : {len(pages)} pages, {len(items)} items")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path("tests/fixtures/private"))
    asyncio.run(export(parser.parse_args().out))
