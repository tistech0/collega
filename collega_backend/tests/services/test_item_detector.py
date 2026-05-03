"""Tests ItemDetector — détection ECNi via tableau Rang/Rubrique/Intitulé.

Les tests couvrent :
  - Extraction du rang depuis les tables pdfplumber (chemin principal)
  - Fallback pytesseract : détection rang depuis le texte brut "Rang Rubrique …"
  - Délimitation du contenu item (du header jusqu'au header suivant)
  - Filtrage des références inline ("voir item N" dans le corps du texte)
  - Priorité des rangs : A > B > C
"""
import pytest

from app.services.ocr.item_detector import ItemDetector

# ── Fixtures détecteur ────────────────────────────────────────────────────────


@pytest.fixture
def detector():
    return ItemDetector()


# ── Données de test ───────────────────────────────────────────────────────────

# Page d'en-tête Item 75 (texte seul — sans table)
PAGE_ITEM_75 = "Collège de Pneumologie - 2023\n\nItem 75\nAddiction au tabac.\n"

# Table Rang/Rubrique/Intitulé pdfplumber pour Item 75 (A et B mélangés)
TABLE_ITEM_75 = [
    ["Rang", "Rubrique", "Intitulé connaissance"],
    ["A", "Définition", "Connaître les principaux risques liés au tabac"],
    ["A", "Épidémiologie", "Connaître l'âge de début"],
    ["B", "Physiopathologie", "Connaître la toxicité de la nicotine"],
]

# Page d'en-tête Item 110 (table avec seulement Rang B)
PAGE_ITEM_110 = "Collège de Pneumologie - 2023\n\nItem 110\nTroubles du sommeil.\n"
TABLE_ITEM_110_ONLY_B = [
    ["Rang", "Rubrique", "Intitulé connaissance"],
    ["B", "Diagnostic positif", "Savoir évaluer une hypersomnolence"],
    ["B", "Épidémiologie", "Connaître l'importance épidémiologique du SAS"],
]

# Page d'en-tête Item 200 (table avec seulement Rang C)
PAGE_ITEM_200 = "Item 200\nTitre item 200.\n"
TABLE_ITEM_200_ONLY_C = [
    ["Rang", "Rubrique", "Intitulé connaissance"],
    ["C", "Spécialité", "Connaître un traitement avancé"],
]

# Page de contenu (pas d'en-tête, pas de table)
PAGE_CONTENT = "I. INTRODUCTION\n\nContenu du cours ici.\n"

# Format pytesseract : tableau rendu en texte brut, sans structure pdfplumber
PAGE_PYTESSERACT_HEADER = (
    "Item 330\nOncologie médicale.\n"
    "Rang Rubrique Intitulé\n"
    "A Définition Connaître les critères diagnostiques\n"
    "B Traitement Connaître les protocoles de chimiothérapie\n"
)

# Page avec un chapitre (pour test extraction chapter_title)
PAGE_WITH_CHAPTER = "Chapitre Cardiologie et maladies vasculaires\n\nItem 1\nTitre.\n"
TABLE_SIMPLE_A = [
    ["Rang", "Rubrique", "Intitulé"],
    ["A", "Définition", "Connaître"],
]

# Référence inline : "item 42" apparaît après 400+ caractères de contenu
# (doit être ignoré — pas un vrai en-tête d'item)
_LONG_BODY = "Ce chapitre traite de l'addiction au tabac en détail. " * 9  # ~477 chars
PAGE_CROSS_REF = "I. INTRODUCTION\n\n" + _LONG_BODY + "Voir item 42 pour le traitement.\n"


# ── Tests unitaires : _rang_from_tables ──────────────────────────────────────


class TestRangFromTables:
    def test_rang_a_when_a_rows_present(self, detector):
        assert detector._rang_from_tables([TABLE_ITEM_75]) == "A"

    def test_rang_b_when_only_b_rows(self, detector):
        assert detector._rang_from_tables([TABLE_ITEM_110_ONLY_B]) == "B"

    def test_rang_c_when_only_c_rows(self, detector):
        assert detector._rang_from_tables([TABLE_ITEM_200_ONLY_C]) == "C"

    def test_priority_a_over_b_and_c(self, detector):
        """Table avec A, B, C mélangés → rang A (priorité A > B > C)."""
        table = [
            ["Rang", "Rubrique", "Intitulé"],
            ["B", "Def", "..."],
            ["C", "Spec", "..."],
            ["A", "Étiologie", "..."],
        ]
        assert detector._rang_from_tables([table]) == "A"

    def test_priority_b_over_c(self, detector):
        table = [
            ["Rang", "Rubrique", "Intitulé"],
            ["C", "Spec", "..."],
            ["B", "Def", "..."],
        ]
        assert detector._rang_from_tables([table]) == "B"

    def test_none_when_no_rang_column(self, detector):
        table = [["Colonne1", "Colonne2"], ["val1", "val2"]]
        assert detector._rang_from_tables([table]) is None

    def test_none_when_tables_empty(self, detector):
        assert detector._rang_from_tables([]) is None

    def test_handles_none_cells_gracefully(self, detector):
        table = [
            ["Rang", "Rubrique", "Intitulé"],
            [None, "Rubrique1", "..."],
            ["A", "Rubrique2", "..."],
        ]
        assert detector._rang_from_tables([table]) == "A"

    def test_rang_column_case_insensitive(self, detector):
        table = [
            ["RANG", "Rubrique", "Intitulé"],
            ["B", "Def", "..."],
        ]
        assert detector._rang_from_tables([table]) == "B"


# ── Tests unitaires : _rang_from_text (fallback pytesseract) ─────────────────


class TestRangFromText:
    def test_detects_rang_from_pytesseract_text(self, detector):
        rang = detector._rang_from_text(PAGE_PYTESSERACT_HEADER)
        assert rang == "A"

    def test_priority_a_over_b_in_text(self, detector):
        text = "Item 1\nRang Rubrique Intitulé\nB Définition ...\nA Étiologie ...\n"
        assert detector._rang_from_text(text) == "A"

    def test_returns_none_without_table_header(self, detector):
        """Texte sans 'Rang Rubrique' → pas de détection rang par texte."""
        assert detector._rang_from_text("Item 75\nContenu sans tableau.") is None

    def test_stops_at_section_header(self, detector):
        """Arrêt du parsing quand on atteint une section de contenu (I. INTRODUCTION)."""
        text = (
            "Item 1\nRang Rubrique Intitulé\n"
            "B Définition ...\n"
            "I. INTRODUCTION\n"
            "A Faux rang après section\n"
        )
        rang = detector._rang_from_text(text)
        # Seulement "B" avant la section, pas "A" après
        assert rang == "B"


# ── Tests d'intégration : detect_items ───────────────────────────────────────


class TestDetectItems:
    def test_detects_single_item_with_table(self, detector):
        items = detector.detect_items([PAGE_ITEM_75], page_tables=[[TABLE_ITEM_75]])
        assert len(items) == 1
        assert items[0].item_number == 75
        assert items[0].rang == "A"

    def test_detects_multiple_items(self, detector):
        pages = [PAGE_ITEM_75, PAGE_CONTENT, PAGE_CONTENT, PAGE_ITEM_110]
        tables = [[TABLE_ITEM_75], [], [], [TABLE_ITEM_110_ONLY_B]]
        items = detector.detect_items(pages, page_tables=tables)
        assert len(items) == 2
        assert {i.item_number for i in items} == {75, 110}

    def test_item_boundaries_header_to_next_header(self, detector):
        """Item 75 → pages 0–2 ; Item 110 → pages 3–5."""
        pages = [PAGE_ITEM_75] + [PAGE_CONTENT] * 2 + [PAGE_ITEM_110] + [PAGE_CONTENT] * 2
        tables = [[TABLE_ITEM_75], [], [], [TABLE_ITEM_110_ONLY_B], [], []]
        items = detector.detect_items(pages, page_tables=tables)
        item_75 = next(i for i in items if i.item_number == 75)
        item_110 = next(i for i in items if i.item_number == 110)
        assert item_75.start_page == 0 and item_75.end_page == 2
        assert item_110.start_page == 3 and item_110.end_page == 5

    def test_last_item_extends_to_end_of_document(self, detector):
        pages = [PAGE_ITEM_75] + [PAGE_CONTENT] * 4
        tables = [[TABLE_ITEM_75]] + [[] for _ in range(4)]
        items = detector.detect_items(pages, page_tables=tables)
        assert items[0].end_page == 4

    def test_rang_b_item(self, detector):
        items = detector.detect_items([PAGE_ITEM_110], page_tables=[[TABLE_ITEM_110_ONLY_B]])
        assert items[0].rang == "B"

    def test_rang_c_item(self, detector):
        items = detector.detect_items([PAGE_ITEM_200], page_tables=[[TABLE_ITEM_200_ONLY_C]])
        assert items[0].rang == "C"

    def test_pytesseract_fallback_rang(self, detector):
        """Sans table pdfplumber, le rang est détecté depuis le texte OCR brut."""
        items = detector.detect_items([PAGE_PYTESSERACT_HEADER], page_tables=[[]])
        assert len(items) == 1
        assert items[0].rang == "A"

    def test_no_tables_arg_defaults_to_text_fallback(self, detector):
        """page_tables=None → détection rang depuis le texte (fallback automatique)."""
        items = detector.detect_items([PAGE_PYTESSERACT_HEADER])
        assert len(items) == 1
        assert items[0].rang == "A"

    def test_cross_reference_ignored(self, detector):
        """'Item 42' à position > 400 chars sans signal rang → ignoré."""
        items = detector.detect_items([PAGE_CROSS_REF], page_tables=[[]])
        assert items == []

    def test_item_n_degree_pattern(self, detector):
        """Supporte 'Item n°42'."""
        page = "Item n°42\nTitre\n"
        table = [["Rang", "Rubrique", "Intitulé"], ["A", "Def", "..."]]
        items = detector.detect_items([page], page_tables=[[table]])
        assert items[0].item_number == 42

    def test_item_uppercase(self, detector):
        """Supporte 'ITEM 15' (insensible à la casse)."""
        page = "ITEM 15\nHypertension artérielle.\n"
        table = [["Rang", "Rubrique", "Intitulé"], ["B", "Def", "..."]]
        items = detector.detect_items([page], page_tables=[[table]])
        assert items[0].item_number == 15

    def test_ocr_text_contains_all_item_pages(self, detector):
        """Le texte OCR de l'item inclut le contenu de toutes ses pages."""
        pages = [PAGE_ITEM_75, "contenu page 1 spécifique", "contenu page 2 spécifique"]
        tables = [[TABLE_ITEM_75], [], []]
        items = detector.detect_items(pages, page_tables=tables)
        assert "contenu page 1 spécifique" in items[0].ocr_text
        assert "contenu page 2 spécifique" in items[0].ocr_text

    def test_confidence_score_averaged_over_item_pages(self, detector):
        pages = [PAGE_ITEM_75, PAGE_CONTENT]
        tables = [[TABLE_ITEM_75], []]
        scores = [0.8, 0.9]
        items = detector.detect_items(pages, scores, page_tables=tables)
        assert items[0].ocr_confidence_score == pytest.approx(0.85, abs=0.01)

    def test_chapter_extracted_from_page(self, detector):
        items = detector.detect_items([PAGE_WITH_CHAPTER], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title != ""
        assert "cardiologie" in items[0].chapter_title.lower()

    def test_empty_pages_returns_empty(self, detector):
        assert detector.detect_items(["", "   ", "\n\n"]) == []

    def test_no_pages_returns_empty(self, detector):
        assert detector.detect_items([]) == []

    def test_default_rang_a_with_warning_when_no_signal(self, detector):
        """Item N en tout début de page mais sans signal rang → rang 'A' par défaut."""
        page = "Item 99\nTitre sans tableau ni rang dans le texte.\n"
        items = detector.detect_items([page], page_tables=[[]])
        # Accepté car position < 400 ; rang defaults to "A"
        assert len(items) == 1
        assert items[0].rang == "A"
