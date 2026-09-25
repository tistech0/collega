#!/usr/bin/env python3
"""Exporte la table `tester_feedbacks` en CSV avant sa suppression (chantier 5, R2).

Lecture SQL brute (le modèle ORM n'existe plus) via `DATABASE_URL` ; chaque avis
est joint au contenu de sa fiche (recto, verso, rang). Écrit
`tester_feedbacks_<AAAAMMJJ>.csv` dans le dossier courant (ou `--out`) et affiche
le nombre de lignes. Si la table n'existe plus (migration 019 déjà passée) :
message et code 0.

Sur le NAS, AVANT la migration 019 — l'image de prod ne contient pas ce script,
donc on le pipe par l'entrée standard (cf. docs/deployment.md) :
  docker exec -i collega-api-1 python - --out /tmp/collega_pdfs < scripts/export_tester_feedbacks.py
puis rapatrier le fichier.
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import os
import sys
from datetime import date
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

_QUERY = text(
    "SELECT tf.*, fc.recto, fc.verso, fc.rang"
    " FROM tester_feedbacks tf"
    " LEFT JOIN flash_cards fc ON fc.id = tf.flash_card_id"
    " ORDER BY tf.created_at, tf.id"
)


async def export_tester_feedbacks(database_url: str, out_dir: Path, *, today: date | None = None) -> Path | None:
    """Écrit le CSV et renvoie son chemin ; None si la table n'existe plus."""
    engine = create_async_engine(database_url)
    try:
        async with engine.connect() as conn:
            exists = (await conn.execute(text("SELECT to_regclass('public.tester_feedbacks')"))).scalar()
            if exists is None:
                return None
            result = await conn.execute(_QUERY)
            columns = list(result.keys())
            rows = result.all()
    finally:
        await engine.dispose()

    path = out_dir / f"tester_feedbacks_{(today or date.today()).strftime('%Y%m%d')}.csv"
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        writer.writerows(rows)
    return path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=Path.cwd(), help="dossier de sortie (défaut : dossier courant)")
    args = parser.parse_args(argv)

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL non définie.", file=sys.stderr)
        return 1

    path = asyncio.run(export_tester_feedbacks(database_url, args.out))
    if path is None:
        print("La table tester_feedbacks n'existe plus : rien à exporter.")
        return 0
    with path.open(encoding="utf-8") as f:
        count = sum(1 for _ in csv.reader(f)) - 1
    print(f"{count} ligne(s) exportée(s) dans {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
