#!/usr/bin/env python3
"""Mesure des tokens d'entrée avant/après `clean_for_prompt` (chantier 4, spec § 5).

Pour chaque collège (`college_<n>.json` du dossier `--fixtures`) et chaque item du
découpage actuel, compte (`messages.count_tokens`, gratuit) les tokens du message de
génération construit exactement comme `ClaudeClient.generate_cards` (modèle, prompt
système p2, message « Item N — titre / <texte_item> ») :
- « brut » : pages de l'item jointes telles quelles ;
- « allégé » : `clean_for_prompt(pages)` (texte réellement envoyé ; vide → aucun
  appel en génération, compté 0).

Sortie : JSON (`--out`) et tableau markdown sur la sortie standard — nombres
seulement, jamais de texte. Ni base ni Redis ; clé `CLAUDE_API_KEY` requise.

    python -m scripts.measure_prompt_tokens --fixtures /fixtures --out /out/measure.json
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

# En premier : réglages factices avant l'import de la configuration.
from scripts.generation_fixtures import FixtureItem, fixture_files, load_items

# isort: split
import anthropic

from app.core.config import settings
from app.services.generation.claude_client import GENERATION_MODEL, GENERATION_SYSTEM_PROMPT, _item_message
from app.services.generation.prompt_text import clean_for_prompt

# count_tokens a sa propre limite de débit : peu d'appels simultanés, reprises du SDK sur 429.
_CONCURRENCY = 4
_MAX_RETRIES = 5


@dataclass
class ItemMeasure:
    item_number: int
    pages: int
    chars_raw: int
    chars_cleaned: int
    tokens_raw: int
    tokens_cleaned: int


def _reduction_pct(before: int, after: int) -> float:
    return round(100 * (before - after) / before, 1) if before else 0.0


def _totals(measures: list[ItemMeasure]) -> dict[str, Any]:
    chars_raw = sum(m.chars_raw for m in measures)
    chars_cleaned = sum(m.chars_cleaned for m in measures)
    tokens_raw = sum(m.tokens_raw for m in measures)
    tokens_cleaned = sum(m.tokens_cleaned for m in measures)
    return {
        "items": len(measures),
        "chars_raw": chars_raw,
        "chars_cleaned": chars_cleaned,
        "tokens_raw": tokens_raw,
        "tokens_cleaned": tokens_cleaned,
        "chars_reduction_pct": _reduction_pct(chars_raw, chars_cleaned),
        "tokens_reduction_pct": _reduction_pct(tokens_raw, tokens_cleaned),
    }


async def _count(client: Any, message: str) -> int:
    response = await client.messages.count_tokens(
        model=GENERATION_MODEL,
        system=GENERATION_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": message}],
    )
    return int(response.input_tokens)


async def measure_item(client: Any, item: FixtureItem, semaphore: asyncio.Semaphore) -> ItemMeasure:
    raw = item.raw_text
    cleaned = clean_for_prompt(item.pages)
    async with semaphore:
        tokens_raw = await _count(client, _item_message(item.item_number, item.title, raw))
        # Texte allégé vide : generate_cards ne fait aucun appel.
        tokens_cleaned = (
            await _count(client, _item_message(item.item_number, item.title, cleaned)) if cleaned.strip() else 0
        )
    return ItemMeasure(
        item_number=item.item_number,
        pages=len(item.pages),
        chars_raw=len(raw),
        chars_cleaned=len(cleaned),
        tokens_raw=tokens_raw,
        tokens_cleaned=tokens_cleaned,
    )


async def run(fixtures: Path, client: Any) -> dict[str, Any]:
    semaphore = asyncio.Semaphore(_CONCURRENCY)
    colleges: dict[str, Any] = {}
    every: list[ItemMeasure] = []
    for college, path in fixture_files(fixtures).items():
        items = load_items(college, path)
        measures = list(await asyncio.gather(*(measure_item(client, it, semaphore) for it in items)))
        every += measures
        colleges[college] = {**_totals(measures), "per_item": [asdict(m) for m in measures]}
    return {"model": GENERATION_MODEL, "colleges": colleges, "total": _totals(every)}


def render(report: dict[str, Any]) -> str:
    """Tableau markdown par collège (nombres seulement)."""
    lines = [
        f"Tokens d'entrée du message de génération ({report['model']}, count_tokens), brut → allégé",
        "",
        "| collège | items | caractères brut | caractères allégé | tokens brut | tokens allégé | réduction tokens |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    rows = [(f"collège {c}", t) for c, t in report["colleges"].items()] + [("**total**", report["total"])]
    for label, t in rows:
        lines.append(
            f"| {label} | {t['items']} | {t['chars_raw']} | {t['chars_cleaned']} | {t['tokens_raw']}"
            f" | {t['tokens_cleaned']} | {t['tokens_reduction_pct']} % |"
        )
    return "\n".join(lines)


def build_client() -> anthropic.AsyncAnthropic:
    return anthropic.AsyncAnthropic(api_key=settings.claude_api_key, max_retries=_MAX_RETRIES)


def main(argv: list[str] | None = None, client: Any = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fixtures", type=Path, required=True, help="dossier des college_<n>.json")
    parser.add_argument("--out", type=Path, required=True, help="fichier JSON de résultat")
    args = parser.parse_args(argv)

    if not fixture_files(args.fixtures):
        print(f"Aucune fixture college_<n>.json dans {args.fixtures}", file=sys.stderr)
        return 2
    if client is None:
        if not settings.claude_api_key.strip():
            print("CLAUDE_API_KEY manquante", file=sys.stderr)
            return 2
        client = build_client()
    report = asyncio.run(run(args.fixtures, client))
    args.out.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    print(render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
