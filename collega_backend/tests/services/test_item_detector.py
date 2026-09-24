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
        text = "Item 1\nRang Rubrique Intitulé\nB Définition ...\nI. INTRODUCTION\nA Faux rang après section\n"
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

    def test_chapter_line_is_not_a_title_source(self, detector):
        """Story 8.0 : « Chapitre … » dans le texte ne produit plus de titre (bruit en prod)."""
        items = detector.detect_items([PAGE_WITH_CHAPTER], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == ""

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


# ── Story 8.0 : titres d'items ────────────────────────────────────────────────

# Format CNEC : « Item N » en en-tête courant sur chaque page, titre dans « OBJECTIFS: N° N. … »
CNEC_290_P1 = (
    "Item 290\n"
    "OBJECTIFS: N° 290. Épidémiologie, facteurs de risque, prévention et dépistage des cancers\n"
    "-+\nDécrire l'épidémiologie des cancers les plus fréquents.\n"
)
CNEC_290_P2 = "Item 290\n• Les recommandations sont de ne pas dépasser dix verres par semaine.\n"
CNEC_291_P1 = (
    "Item 291\nOBJECTIFS : N° 291. Cancer : cancérogenèse, oncogénétique\n➔ Décrire l'histoire naturelle du cancer.\n"
)
CNEC_TOC = (
    "SOMMAIRE\n"
    "Chapitre 16 : Tumeurs de l'ovaire .......................... 271\n"
    "Item 306\n"
    "Chapitre 17 : Tumeurs des os primitives et secondaires ..... 287\n"
    "Item 307\n"
    "Chapitre 18 : Tumeurs du pancréas .......................... 307\n"
    "Item 308\n"
)


class TestTitleExtraction:
    def test_title_on_same_line_with_dash(self, detector):
        page = "Item 310 – Tumeurs du testicule\nRang Rubrique Intitulé\n"
        items = detector.detect_items([page], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == "Tumeurs du testicule"

    @pytest.mark.parametrize("sep", [":", "-", "."])
    def test_title_on_same_line_other_separators(self, detector, sep):
        page = f"Item 311 {sep} Tumeurs du rein\n"
        items = detector.detect_items([page], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == "Tumeurs du rein"

    def test_title_on_next_line(self, detector):
        items = detector.detect_items([PAGE_ITEM_75], page_tables=[[TABLE_ITEM_75]])
        assert items[0].chapter_title == "Addiction au tabac"

    def test_title_wrapped_on_two_lines(self, detector):
        page = (
            "Collège des Enseignants de Pneumologie - 2023\nItem 154\n"
            "Infections broncho-pulmonaires\ncommunautaires de l’adulte.\n"
            "Rang Rubrique Intitulé\n"
        )
        items = detector.detect_items([page], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == ("Infections broncho-pulmonaires communautaires de l’adulte")

    def test_single_word_title(self, detector):
        page = "Item 360\nPneumothorax\nRang Rubrique Intitulé\n"
        items = detector.detect_items([page], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == "Pneumothorax"

    def test_body_text_after_header_is_not_a_title(self, detector):
        items = detector.detect_items([CNEC_290_P2], page_tables=[[]])
        assert items[0].chapter_title == ""

    def test_objectifs_line_gives_title(self, detector):
        items = detector.detect_items([CNEC_291_P1], page_tables=[[]])
        assert items[0].chapter_title == "Cancer : cancérogenèse, oncogénétique"

    def test_objectifs_wrapped_title(self, detector):
        page = (
            "Item 292\nOBJECTIFS: N° 292. Diagnostic des cancers: signes d'appel et "
            "investigations paracliniques; caractérisation du\nstade ; pronostic\n-+\n"
            "Décrire les principes du raisonnement diagnostique.\n"
        )
        items = detector.detect_items([page], page_tables=[[]])
        assert items[0].chapter_title == (
            "Diagnostic des cancers: signes d'appel et investigations paracliniques; "
            "caractérisation du stade ; pronostic"
        )

    def test_objectifs_ocr_variant(self, detector):
        page = 'Item 300\nOBJECTIFS: N"o300. Tumeurs du col utérin et du corps utérin\n-+ Éléments\n'
        items = detector.detect_items([page], page_tables=[[]])
        assert items[0].chapter_title == "Tumeurs du col utérin et du corps utérin"

    def test_objectifs_wins_over_header_line(self, detector):
        page = (
            "Item 304\nTumeurs du foie,\n►-p-ri-m-it-i_ve_s\n"
            "OBJECTIFS: N° 304. Tumeurs du foie, primitives et secondaires\n➔ Éléments\n"
        )
        items = detector.detect_items([page], page_tables=[[]])
        assert items[0].chapter_title == "Tumeurs du foie, primitives et secondaires"

    def test_objectifs_on_later_page_of_the_item(self, detector):
        pages = ["Item 299\nIntroduction du chapitre\n", "Item 299\nOBJECTIFS: N° 299. Tumeurs intracrâniennes\n-+\n"]
        items = detector.detect_items(pages, page_tables=[[], []])
        assert items[0].chapter_title == "Tumeurs intracrâniennes"


class TestRunningHeadersAndToc:
    def test_consecutive_pages_same_number_form_one_item(self, detector):
        pages = [CNEC_290_P1, CNEC_290_P2, CNEC_291_P1]
        items = detector.detect_items(pages, page_tables=[[], [], []])
        assert [i.item_number for i in items] == [290, 291]
        assert (items[0].start_page, items[0].end_page) == (0, 1)
        assert "dix verres" in items[0].ocr_text
        assert (items[1].start_page, items[1].end_page) == (2, 2)

    def test_merged_span_takes_best_rang(self, detector):
        pages = ["Item 297\nIntro\n", "Item 297\nsuite\n"]
        tables = [[TABLE_ITEM_200_ONLY_C], [TABLE_ITEM_110_ONLY_B]]
        items = detector.detect_items(pages, page_tables=tables)
        assert len(items) == 1
        assert items[0].rang == "B"

    def test_toc_page_does_not_create_item(self, detector):
        pages = [CNEC_TOC, CNEC_290_P1, CNEC_290_P2]
        items = detector.detect_items(pages, page_tables=[[], [], []])
        assert [i.item_number for i in items] == [290]
        assert items[0].start_page == 1


class TestProdCorpusEdgeCases:
    """Cas relevés sur les PDF de prod (CEP 2023, CNEC 4e éd.) — story 8.0."""

    def test_header_with_leading_punctuation_is_detected(self, detector):
        pages = ["Item 312\nOBJECTIFS: N° 312. Tumeurs du sein\n", ". Item 313\nTumeurs du testicule\n"]
        items = detector.detect_items(pages, page_tables=[[], []])
        assert [i.item_number for i in items] == [312, 313]
        assert items[1].chapter_title == "Tumeurs du testicule"

    def test_toc_gives_title_when_no_objectifs(self, detector):
        toc = (
            "SOMMAIRE\n►\n"
            "Chapitre 17 : Tumeurs des os primitives et secondaires .......... 287\nItem 307\n"
            "Chapitre 18 : Tumeurs du pancréas ...............................\n307\nItem 308\n"
            "C' a ire 13 : Tumeurs de l'estomac ................ 213\nItem 303\n"
        )
        pages = [toc, "Item 308\n1.2. Facteurs de risque\n", "Item 308\nN - Adénopathies régionales\n"]
        items = detector.detect_items(pages, page_tables=[[], [], []])
        assert [i.item_number for i in items] == [308]
        assert items[0].chapter_title == "Tumeurs du pancréas"

    def test_header_title_read_on_first_page_only(self, detector):
        pages = ["Item 308\n1.2. Facteurs de risque\n", "Item 308\nN - Adénopathies régionales\n"]
        items = detector.detect_items(pages, page_tables=[[], []])
        assert items[0].chapter_title == ""

    def test_broken_drop_cap_is_rejected(self, detector):
        page = "Item 338\nŒ Q A\nDEME DE UINCKE ET NAPHYLAXIE\nRang Rubrique Intitulé\n"
        items = detector.detect_items([page], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == ""

    def test_all_caps_title_becomes_sentence_case(self, detector):
        page = "Item 204\nTOUX CHEZ L’ADULTE\nRang Rubrique Intitulé\n"
        items = detector.detect_items([page], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == "Toux chez l’adulte"

    def test_truncated_running_header_is_ignored(self, detector):
        """« tem 30 » (en-tête « Item 306 » tronqué des deux côtés) ne crée pas d'item 30."""
        pages = ["Item 306\nTumeurs de l'ovaire\n", "tem 30\nClinique\n", "Item 306\n4. Démarche\n"]
        items = detector.detect_items(pages, page_tables=[[], [], []])
        assert [(i.item_number, i.start_page, i.end_page) for i in items] == [(306, 0, 2)]

    def test_objectifs_title_on_next_line(self, detector):
        page = "Item 304\nOBJECTIFS: N° 304.\nTumeurs du foie, primitives et secondaires\n➔ Éléments\n"
        items = detector.detect_items([page], page_tables=[[]])
        assert items[0].chapter_title == "Tumeurs du foie, primitives et secondaires"


class TestReviewFindings:
    """Retours de revue story 8.0 — un mauvais titre se propagerait via le référentiel global."""

    def test_table_header_is_not_a_title(self, detector):
        page = "Item 75\nRang Rubrique Intitulé Descriptif\nA Définition Connaître\n"
        items = detector.detect_items([page], page_tables=[[TABLE_SIMPLE_A]])
        assert items[0].chapter_title == ""

    def test_running_header_span_ignores_header_line(self, detector):
        """Format CNEC (en-tête répété) : la ligne sous « Item N » est du corps de texte."""
        pages = ["Item 290\nIntroduction\n", "Item 290\nÉpidémiologie\n"]
        items = detector.detect_items(pages, page_tables=[[], []])
        assert items[0].chapter_title == ""

    def test_related_items_list_does_not_make_header_a_toc(self, detector):
        page = "Item 75\nAddiction au tabac.\nItems liés :\n- Item 12\n- Item 45\n• Item 46\n"
        items = detector.detect_items([page, "Item 76\nTitre suivant correct\n"], page_tables=[[TABLE_ITEM_75], []])
        assert [i.item_number for i in items] == [75, 76]
        assert items[0].chapter_title == "Addiction au tabac"

    def test_bulleted_reference_is_not_a_header(self, detector):
        pages = [PAGE_ITEM_75, "• Item 230 évoqué ici\nsuite du texte\n"]
        items = detector.detect_items(pages, page_tables=[[TABLE_ITEM_75], []])
        assert [(i.item_number, i.start_page, i.end_page) for i in items] == [(75, 0, 1)]

    def test_toc_with_title_below_number_is_ignored(self, detector):
        """Sommaire « Item N \\n Titre » : le tampon serait décalé d'un rang → rejeté."""
        toc = (
            "SOMMAIRE\nItem 306\nTumeurs du col utérin ...... 12\n"
            "Item 307\nTumeurs de l'ovaire ...... 30\nItem 308\nTumeurs du pancréas ...... 44\n"
        )
        pages = [toc, "Item 307\nTumeurs de l'ovaire\n"]
        items = detector.detect_items(pages, page_tables=[[], []])
        assert items[0].chapter_title == "Tumeurs de l'ovaire"

    def test_non_adjacent_repeat_keeps_header_title(self, detector):
        """CEP : « Item 359 bis » 14 pages plus loin n'est pas un en-tête courant."""
        pages = [
            "Item 359\nDétresse respiratoire de l’adulte\nRang Rubrique\n",
            "suite",
            "Item 359 bis\nDétresse de l'enfant\n",
        ]
        items = detector.detect_items(pages, page_tables=[[TABLE_SIMPLE_A], [], []])
        assert items[0].chapter_title == "Détresse respiratoire de l’adulte"
