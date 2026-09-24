#!/usr/bin/env python3
"""Contrôle de fumée de la génération p2 (chantier 4, spec § 9) — hors CI, clé réelle,
quelques centimes.

Sur un item par collège (`college_<n>.json` du dossier `--fixtures`, découpage
actuel), appelle le vrai `ClaudeClient.generate_cards` avec l'effort `low` puis
`medium` et relève pour chaque appel : nombre de fiches, répartition par rang et
par type, tokens d'entrée/sortie (la réflexion est comptée dans la sortie), coût,
`insufficient_text`, `stop_reason`, durée ; et vérifie automatiquement que chaque
nombre d'un verso figure dans le texte source de l'item.

Items par défaut : collège 12 → le plus long (caractères bruts), les autres →
l'item médian ; `--items 3:305,12:216,34:209` pour les choisir.

Sorties : JSON complet (`--out`, fiches comprises — reste sur le serveur) et, sur la
sortie standard, un résumé markdown : tableaux de nombres et au plus 3 fiches
d'exemple par item (recto/verso tronqués à 120 caractères). Jamais de texte source.

    python -m scripts.smoke_generation --fixtures /fixtures --out /out/smoke.json
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any

# En premier : réglages factices avant l'import de la configuration.
from scripts.generation_fixtures import FixtureItem, fixture_files, load_items

# isort: split
import anthropic

from app.core.config import settings
from app.services.generation.claude_client import (
    CARD_RANGS,
    CARD_TYPES,
    GENERATION_MODEL,
    CardGenResult,
    ClaudeClient,
    Effort,
)
from app.services.generation.token_cost import compute_cost_eur, cost_usd

EFFORTS: tuple[Effort, ...] = ("low", "medium")
# Choix par défaut de l'item : le plus long pour ce collège, l'item médian ailleurs.
_LARGEST_FOR = frozenset({"12"})
_NUMBER = re.compile(r"\d+(?:[.,]\d+)?")
_MAX_UNMATCHED_EXAMPLES = 5
_FRAGMENT_CHARS = 60
_MAX_EXAMPLE_CARDS = 3
_EXAMPLE_CHARS = 120


def _norm_number(n: str) -> str:
    return n.replace(",", ".")


def numbers_in(text: str) -> set[str]:
    """Nombres d'un texte, virgule décimale ramenée au point (« 0,5 » = « 0.5 »)."""
    return {_norm_number(m.group()) for m in _NUMBER.finditer(text)}


def _fragment(text: str, start: int, end: int) -> str:
    """Extrait d'au plus `_FRAGMENT_CHARS` caractères centré sur [start, end)."""
    margin = max(0, (_FRAGMENT_CHARS - (end - start)) // 2)
    lo = max(0, start - margin)
    return text[lo : lo + _FRAGMENT_CHARS].replace("\n", " ")


def check_numbers(cards: list[Any], source: str) -> dict[str, Any]:
    """Nombres des versos absents du texte source : total et quelques extraits."""
    known = numbers_in(source)
    unmatched = 0
    examples: list[str] = []
    for card in cards:
        for m in _NUMBER.finditer(card.verso):
            if _norm_number(m.group()) in known:
                continue
            unmatched += 1
            if len(examples) < _MAX_UNMATCHED_EXAMPLES:
                examples.append(_fragment(card.verso, m.start(), m.end()))
    return {"unmatched_numbers": unmatched, "unmatched_examples": examples}


def parse_items(spec: str) -> dict[str, int]:
    """« 3:305,12:216 » → {"3": 305, "12": 216}."""
    chosen: dict[str, int] = {}
    for part in filter(None, (p.strip() for p in spec.split(","))):
        college, sep, number = part.partition(":")
        if not sep or not number.strip().isdigit():
            raise ValueError(f"--items : « {part} » n'est pas de la forme collège:item")
        chosen[college.strip()] = int(number)
    return chosen


def default_item(college: str, items: list[FixtureItem]) -> FixtureItem:
    by_size = sorted(items, key=lambda it: (len(it.raw_text), it.item_number))
    return by_size[-1] if college in _LARGEST_FOR else by_size[len(by_size) // 2]


def select_items(fixtures: Path, chosen: dict[str, int] | None) -> list[FixtureItem]:
    files = fixture_files(fixtures)
    if chosen:
        missing = sorted(set(chosen) - set(files))
        if missing:
            raise ValueError(f"fixture absente pour le(s) collège(s) {', '.join(missing)}")
    selected: list[FixtureItem] = []
    for college, path in files.items():
        if chosen and college not in chosen:
            continue
        items = load_items(college, path)
        if not items:
            raise ValueError(f"collège {college} : aucun item détecté")
        if chosen:
            match = [it for it in items if it.item_number == chosen[college]]
            if not match:
                raise ValueError(f"collège {college} : item {chosen[college]} absent du découpage")
            selected.append(match[0])
        else:
            selected.append(default_item(college, items))
    return selected


def run_record(item: FixtureItem, effort: Effort, result: CardGenResult, duration_s: float) -> dict[str, Any]:
    return {
        "effort": effort,
        "cards": len(result.cards),
        "by_rang": {r: n for r in CARD_RANGS if (n := sum(c.rang == r for c in result.cards))},
        "by_type": {t: n for t in CARD_TYPES if (n := sum(c.card_type == t for c in result.cards))},
        "input_tokens": result.input_tokens,
        "output_tokens": result.output_tokens,
        "cost_usd": round(cost_usd(result.model, result.input_tokens, result.output_tokens), 4),
        "cost_eur": compute_cost_eur(result.model, result.input_tokens, result.output_tokens),
        "insufficient_text": result.insufficient_text,
        "stop_reason": result.stop_reason,
        "duration_s": round(duration_s, 1),
        **check_numbers(result.cards, item.raw_text),
        "card_list": [{"type": c.card_type, "rang": c.rang, "recto": c.recto, "verso": c.verso} for c in result.cards],
    }


async def smoke_item(client: ClaudeClient, item: FixtureItem) -> dict[str, Any]:
    runs: list[dict[str, Any]] = []
    for effort in EFFORTS:
        started = time.monotonic()
        try:
            result = await client.generate_cards(item.item_number, item.title, item.pages, effort=effort)
        except anthropic.APIError as exc:
            # Rien de facturé : on note l'erreur et on passe à l'appel suivant.
            runs.append(
                {"effort": effort, "error": type(exc).__name__, "duration_s": round(time.monotonic() - started, 1)}
            )
            continue
        runs.append(run_record(item, effort, result, time.monotonic() - started))
    return {
        "college": item.college,
        "item_number": item.item_number,
        "pages": len(item.pages),
        "chars_raw": len(item.raw_text),
        "runs": runs,
    }


async def run(fixtures: Path, client: ClaudeClient, chosen: dict[str, int] | None = None) -> dict[str, Any]:
    items = select_items(fixtures, chosen)
    # Items l'un après l'autre (et les efforts aussi) : durées comparables, pas de 429.
    results = [await smoke_item(client, item) for item in items]
    totals = Counter[str]()
    for r in results:
        for run_ in r["runs"]:
            if "error" not in run_:
                totals[f"{run_['effort']}_eur"] += run_["cost_eur"]
    return {
        "model": GENERATION_MODEL,
        "efforts": list(EFFORTS),
        "items": results,
        "total_cost_eur": {e: round(totals[f"{e}_eur"], 4) for e in EFFORTS},
    }


def _counts(counts: dict[str, int]) -> str:
    return " ".join(f"{k} {v}" for k, v in counts.items()) or "—"


def _truncate(text: str) -> str:
    text = " ".join(text.split())
    return text if len(text) <= _EXAMPLE_CHARS else text[: _EXAMPLE_CHARS - 1] + "…"


def render(report: dict[str, Any]) -> str:
    """Résumé markdown : tableau des appels et quelques fiches d'exemple par item."""
    lines = [
        f"Contrôle de fumée {report['model']} — effort {' puis '.join(report['efforts'])}",
        "",
        "| collège | item | pages | caractères | effort | fiches | par rang | par type | tokens entrée"
        " | tokens sortie | coût € | insuffisant | stop_reason | durée s | nombres hors source |",
        "|---|---:|---:|---:|---|---:|---|---|---:|---:|---:|---|---|---:|---:|",
    ]
    for item in report["items"]:
        head = f"| {item['college']} | {item['item_number']} | {item['pages']} | {item['chars_raw']}"
        for r in item["runs"]:
            if "error" in r:
                lines.append(
                    f"{head} | {r['effort']} | erreur {r['error']} |  |  |  |  |  |  |  | {r['duration_s']} |  |"
                )
                continue
            lines.append(
                f"{head} | {r['effort']} | {r['cards']} | {_counts(r['by_rang'])} | {_counts(r['by_type'])}"
                f" | {r['input_tokens']} | {r['output_tokens']} | {r['cost_eur']} | {'oui' if r['insufficient_text'] else 'non'}"
                f" | {r['stop_reason']} | {r['duration_s']} | {r['unmatched_numbers']} |"
            )
    lines.append("")
    lines.append("Coût total € : " + ", ".join(f"{e} {c}" for e, c in report["total_cost_eur"].items()))
    for item in report["items"]:
        # Exemples tirés du dernier appel qui a produit des fiches (effort le plus élevé).
        best = next((r for r in reversed(item["runs"]) if r.get("card_list")), None)
        if best is None:
            continue
        cards, effort = best["card_list"], best["effort"]
        lines += ["", f"Exemples — collège {item['college']}, item {item['item_number']} (effort {effort}) :", ""]
        lines += ["| type | rang | recto | verso |", "|---|---|---|---|"]
        for c in cards[:_MAX_EXAMPLE_CARDS]:
            recto, verso = (_truncate(c[k]).replace("|", "/") for k in ("recto", "verso"))
            lines.append(f"| {c['type']} | {c['rang']} | {recto} | {verso} |")
    return "\n".join(lines)


def main(argv: list[str] | None = None, client: ClaudeClient | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fixtures", type=Path, required=True, help="dossier des college_<n>.json")
    parser.add_argument("--out", type=Path, required=True, help="fichier JSON de résultat")
    parser.add_argument("--items", help="items choisis, « collège:item » séparés par des virgules")
    args = parser.parse_args(argv)

    try:
        chosen = parse_items(args.items) if args.items else None
        if not fixture_files(args.fixtures):
            raise ValueError(f"aucune fixture college_<n>.json dans {args.fixtures}")
        if client is None:
            if not settings.claude_api_key.strip():
                raise ValueError("CLAUDE_API_KEY manquante")
            client = ClaudeClient()
        report = asyncio.run(run(args.fixtures, client, chosen))
    except ValueError as exc:
        print(f"Erreur : {exc}", file=sys.stderr)
        return 2
    args.out.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    print(render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
