#!/usr/bin/env python3
"""Rapport de découpage d'un collège (chantier 4, spec § 4) : item → pages, caractères,
objectifs A/B, sections hors item, warnings. Hors ligne : ni base, ni Redis, ni Claude.

Entrée : un PDF (texte extrait par `OcrProcessor` : couche texte, Tesseract seulement pour
une page sans texte) ou une fixture JSON exportée par `scripts/export_page_fixtures.py`.

    .venv/bin/python -m scripts.segmentation_report "HEMATO 5e college.pdf"
    .venv/bin/python -m scripts.segmentation_report tests/fixtures/private/college_12.json \\
        --verite tests/fixtures/segmentation/ground_truth_college_12.json

Le texte des pages n'est jamais affiché (contenu sous droits) : numéros et compteurs seulement.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# Réglages factices : le script n'ouvre ni base ni Redis, mais `app.services.ocr` importe les
# modèles, donc la configuration. Sans effet si les variables sont déjà définies.
for _key, _value in {
    "DATABASE_URL": "postgresql+asyncpg://hors-ligne@localhost/hors-ligne",
    "REDIS_URL": "redis://localhost:6379/0",
    "SECRET_KEY": "segmentation-report-hors-ligne-sans-secret",
    "CLAUDE_API_KEY": "hors-ligne",
    "REVENUECAT_WEBHOOK_SECRET": "hors-ligne",
}.items():
    os.environ.setdefault(_key, _value)

from app.services.ocr.item_detector import ItemDetector, SegmentationResult, page_ranges  # noqa: E402


def load_fixture(path: Path) -> tuple[list[str], list[float], list]:
    pages = json.loads(path.read_text())["pages"]
    return [p["text"] for p in pages], [p["confidence"] for p in pages], [p["tables"] for p in pages]


def load_pdf(path: Path) -> tuple[list[str], list[float], list]:
    from app.services.ocr.ocr_processor import OcrProcessor

    processor = OcrProcessor()
    texts, scores, tables = [], [], []
    for n in range(processor.count_pages(path)):
        page = processor.process_page(path, n)
        texts.append(page.text)
        scores.append(page.confidence_score)
        tables.append(page.tables)
    return texts, scores, tables


def render(result: SegmentationResult) -> str:
    """Tableau lisible du découpage (sans texte de page)."""
    lines = [f"{'item':>5}  {'pages':<14} {'nb':>3} {'caractères':>10}  rang  obj. A/B"]
    for item in result.items:
        content = [p for p in result.report.pages if p.kind == "item" and p.item_number == item.item_number]
        lines.append(
            f"{item.item_number:>5}  {page_ranges(item.pages):<14} {len(content):>3} {len(item.ocr_text):>10}"
            f"  {item.rang:<4}  {item.objectives_a}/{item.objectives_b}"
        )
    lines.append("")
    for section in result.report.sections():
        lines.append(f"section « {section['label']} » : pages {section['pages']}")
    blanks = result.report.blank_pages()
    if blanks:
        lines.append(f"pages blanches ({len(blanks)}) : {page_ranges(blanks)}")
    lines.append("")
    lines.append(f"warnings ({len(result.report.warnings)}) :")
    lines += [f"  - {w}" for w in result.report.warnings]
    lines.append("")
    lines.append(f"Résumé : {result.report.summary()}")
    return "\n".join(lines)


def compare(result: SegmentationResult, truth: dict) -> dict:
    """Écarts avec une vérité terrain (`ground_truth_college_*.json`)."""
    expected = {it["item_number"]: (it["start_page"], it["end_page"]) for it in truth["items"]}
    found = {i.item_number: (i.start_page, i.end_page) for i in result.items}
    content = {p: n for n, (a, b) in expected.items() for p in range(a, b + 1)}
    assigned = {p: i.item_number for i in result.items for p in i.pages}
    sections = {
        p
        for s in truth["non_item_sections"]
        if not s["label"].startswith("page blanche")
        for p in range(s["start_page"], s["end_page"] + 1)
    }
    return {
        "exact": sum(1 for n, span in expected.items() if found.get(n) == span),
        "total": len(expected),
        "not_exact": sorted(n for n, span in expected.items() if found.get(n) != span),
        "false_items": sorted(n for n in found if n not in expected),
        "unassigned": page_ranges([p for p in content if p not in assigned]),
        "misassigned": page_ranges([p for p, n in content.items() if p in assigned and assigned[p] != n]),
        "sections_in_items": page_ranges(sorted(sections & set(assigned))),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="PDF du collège ou fixture JSON")
    parser.add_argument("--verite", type=Path, help="vérité terrain JSON à comparer")
    args = parser.parse_args(argv)

    load = load_pdf if args.source.suffix.lower() == ".pdf" else load_fixture
    texts, scores, tables = load(args.source)
    result = ItemDetector().detect_items(texts, scores, tables)
    print(render(result))
    if args.verite:
        diff = compare(result, json.loads(args.verite.read_text()))
        print(
            f"Vérité terrain : {diff['exact']}/{diff['total']} items exacts ; non exacts {diff['not_exact']} ;"
            f" faux {diff['false_items']} ; pages non rattachées [{diff['unassigned']}] ;"
            f" mal rattachées [{diff['misassigned']}] ; pages hors item dans un item [{diff['sections_in_items']}]"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
