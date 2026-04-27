"""Tests ItemDetector — détection pattern ECNi, aucune dépendance externe."""
import pytest

from app.services.ocr.item_detector import ItemDetector


@pytest.fixture
def detector():
    return ItemDetector()


SAMPLE_ECNi_TEXT_PAGE_0 = """
Chapitre Cardiologie et Maladies Vasculaires

Item 1 - Rang A
La cardiologie est la spécialité médicale consacrée au coeur.
Le diagnostic repose sur l'ECG et l'échographie cardiaque.
Rang A — Connaître les critères diagnostiques.
"""

SAMPLE_ECNi_TEXT_PAGE_1 = """
Item 2 - Rang B
La coronaropathie est une maladie des artères coronaires.
Rang B — Connaître le traitement de première intention.
"""

SAMPLE_ECNi_TEXT_PAGE_2 = """
Item 3 - Rang C
L'endocardite infectieuse est une infection de l'endocarde.
Rang C — Savoir prescrire l'antibiothérapie prophylactique.
"""

SAMPLE_MIXED_ITEM_TEXT = """
Item n°42 - Rang A
Contenu de l'item 42.
"""

SAMPLE_ITEM_UPPERCASE = """
ITEM 15 - Rang B
Hypertension artérielle de l'adulte.
"""


class TestDetectItems:
    def test_detects_multiple_items(self, detector):
        pages = [SAMPLE_ECNi_TEXT_PAGE_0, SAMPLE_ECNi_TEXT_PAGE_1, SAMPLE_ECNi_TEXT_PAGE_2]
        items = detector.detect_items(pages)
        assert len(items) == 3

    def test_detects_item_numbers(self, detector):
        pages = [SAMPLE_ECNi_TEXT_PAGE_0, SAMPLE_ECNi_TEXT_PAGE_1]
        items = detector.detect_items(pages)
        numbers = [i.item_number for i in items]
        assert 1 in numbers
        assert 2 in numbers

    def test_detects_rang_a(self, detector):
        items = detector.detect_items([SAMPLE_ECNi_TEXT_PAGE_0])
        assert items[0].rang == "A"

    def test_detects_rang_b(self, detector):
        items = detector.detect_items([SAMPLE_ECNi_TEXT_PAGE_1])
        assert items[0].rang == "B"

    def test_detects_rang_c(self, detector):
        items = detector.detect_items([SAMPLE_ECNi_TEXT_PAGE_2])
        assert items[0].rang == "C"

    def test_page_boundaries_tracked(self, detector):
        pages = [SAMPLE_ECNi_TEXT_PAGE_0, SAMPLE_ECNi_TEXT_PAGE_1]
        items = detector.detect_items(pages)
        assert items[0].start_page == 0
        assert items[1].start_page == 1

    def test_ocr_text_preserved(self, detector):
        pages = [SAMPLE_ECNi_TEXT_PAGE_0]
        items = detector.detect_items(pages)
        assert "cardiologie" in items[0].ocr_text.lower()

    def test_confidence_score_assigned(self, detector):
        pages = [SAMPLE_ECNi_TEXT_PAGE_0]
        scores = [0.85]
        items = detector.detect_items(pages, page_scores=scores)
        assert items[0].ocr_confidence_score == pytest.approx(0.85, abs=0.001)

    def test_item_n_pattern(self, detector):
        """Supporte 'Item n°42' en plus de 'Item 42'."""
        items = detector.detect_items([SAMPLE_MIXED_ITEM_TEXT])
        assert items[0].item_number == 42

    def test_item_uppercase(self, detector):
        """Supporte 'ITEM 15' (insensible à la casse)."""
        items = detector.detect_items([SAMPLE_ITEM_UPPERCASE])
        assert items[0].item_number == 15

    def test_empty_pages_returns_empty(self, detector):
        items = detector.detect_items(["", "   ", "\n\n"])
        assert items == []

    def test_no_pages_returns_empty(self, detector):
        items = detector.detect_items([])
        assert items == []

    def test_chapter_extracted(self, detector):
        items = detector.detect_items([SAMPLE_ECNi_TEXT_PAGE_0])
        # Le chapitre doit être extrait depuis la ligne "Chapitre ..."
        assert items[0].chapter_title != ""
