"""Découpage des 3 collèges réels comparé à la vérité terrain (chantier 4, spec § 4).

Les textes de pages (sous droits) sont dans tests/fixtures/private/ (hors git) : les tests
sont ignorés s'ils manquent (CI). La vérité terrain (numéros, titres officiels, plages de
pages, aucun texte) est committée dans tests/fixtures/segmentation/.
"""

import json
from pathlib import Path

import pytest

from app.services.ocr.item_detector import ItemDetector, SegmentationResult

FIXTURES = Path(__file__).resolve().parents[2] / "fixtures"
COLLEGES = [3, 12, 34]


def _truth(college: int) -> dict:
    return json.loads((FIXTURES / "segmentation" / f"ground_truth_college_{college}.json").read_text())


def _official_titles(truth: dict) -> dict[int, str]:
    """Référentiel complet simulé : titres officiels du livre + libellés factices pour les autres numéros."""
    titles = {n: f"Intitulé officiel de l'item {n}" for n in range(1, 368)}
    titles.update({it["item_number"]: it["title"] for it in truth["items"]})
    return titles


# (collège, avec référentiel officiel) : le découpage doit atteindre la vérité terrain sans lui.
@pytest.fixture(scope="module", params=[(c, False) for c in COLLEGES] + [(c, True) for c in COLLEGES])
def case(request) -> tuple[dict, SegmentationResult]:
    college, with_referential = request.param
    path = FIXTURES / "private" / f"college_{college}.json"
    if not path.exists():
        pytest.skip(f"fixture privée absente : {path.name}")
    pages = json.loads(path.read_text())["pages"]
    truth = _truth(college)
    result = ItemDetector().detect_items(
        [p["text"] for p in pages],
        [p["confidence"] for p in pages],
        [p["tables"] for p in pages],
        known_titles=_official_titles(truth) if with_referential else None,
    )
    return truth, result


def _content_pages_of(truth: dict) -> dict[int, int]:
    return {p: it["item_number"] for it in truth["items"] for p in range(it["start_page"], it["end_page"] + 1)}


def test_items_match_ground_truth(case):
    truth, result = case
    expected = [(it["item_number"], it["start_page"], it["end_page"]) for it in truth["items"]]
    assert [(i.item_number, i.start_page, i.end_page) for i in result.items] == expected


def test_item_pages_are_exactly_its_range(case):
    truth, result = case
    for item in result.items:
        assert item.pages == list(range(item.start_page, item.end_page + 1))


def test_no_content_page_left_out(case):
    truth, result = case
    assigned = {p: i.item_number for i in result.items for p in i.pages}
    lost = [p for p, n in _content_pages_of(truth).items() if assigned.get(p) != n]
    assert lost == []
    assert not [w for w in result.report.warnings if "non rattachée" in w]


def test_no_section_page_inside_an_item(case):
    truth, result = case
    in_items = {p for i in result.items for p in i.pages}
    section_pages = {
        p
        for s in truth["non_item_sections"]
        if not s["label"].startswith("page blanche")
        for p in range(s["start_page"], s["end_page"] + 1)
    }
    assert sorted(in_items & section_pages) == []


def test_report_covers_every_page_once(case):
    truth, result = case
    assert [p.page for p in result.report.pages] == list(range(truth["page_count"]))
    content = _content_pages_of(truth)
    for p in result.report.pages:
        if p.page in content:
            assert (p.kind, p.item_number) == ("item", content[p.page])
