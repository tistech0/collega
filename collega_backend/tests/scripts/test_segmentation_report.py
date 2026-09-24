"""Chantier 4 — scripts/segmentation_report.py sur une fixture synthétique."""

import json

from app.services.ocr.item_detector import ItemDetector
from scripts.segmentation_report import compare, main, render

BODY = "Texte de cours assez long pour ne pas passer pour une page blanche."
PAGES = [
    "SOMMAIRE\nItem 290 ....... 1\nItem 291 ....... 3\nItem 292 ....... 5\n",
    f"Item 290\nOBJECTIFS: N° 290. Épidémiologie\nRang Rubrique Intitulé\nA Définition x\n{BODY}",
    f"Item 290\n{BODY}",
    f"Item 291\nOBJECTIFS: N° 291. Cancérogenèse\n{BODY}",
    "",
]
TRUTH = {
    "items": [
        {"item_number": 290, "start_page": 1, "end_page": 2},
        {"item_number": 291, "start_page": 3, "end_page": 3},
    ],
    "non_item_sections": [
        {"label": "sommaire", "start_page": 0, "end_page": 0},
        {"label": "page blanche", "start_page": 4, "end_page": 4},
    ],
}


def test_render_lists_items_sections_and_warnings_without_text():
    out = render(ItemDetector().detect_items(PAGES))
    assert "  290  1-2" in out and "A     1/0" in out
    assert "section « sommaire » : pages 0" in out
    assert "pages blanches (1) : 4" in out
    assert "item 291 : moins de 2 pages" in out
    assert BODY not in out and "Épidémiologie" not in out


def test_compare_with_ground_truth():
    diff = compare(ItemDetector().detect_items(PAGES), TRUTH)
    assert (diff["exact"], diff["total"], diff["false_items"], diff["unassigned"]) == (2, 2, [], "")
    truth = {**TRUTH, "items": [{"item_number": 290, "start_page": 1, "end_page": 3}]}
    diff = compare(ItemDetector().detect_items(PAGES), truth)
    assert (diff["exact"], diff["false_items"], diff["misassigned"]) == (0, [291], "3")


def test_main_on_fixture(tmp_path, capsys):
    fixture = tmp_path / "college.json"
    fixture.write_text(json.dumps({"pages": [{"text": t, "confidence": 0.9, "tables": []} for t in PAGES]}))
    truth = tmp_path / "truth.json"
    truth.write_text(json.dumps(TRUTH))
    assert main([str(fixture), "--verite", str(truth)]) == 0
    assert "Vérité terrain : 2/2 items exacts" in capsys.readouterr().out
