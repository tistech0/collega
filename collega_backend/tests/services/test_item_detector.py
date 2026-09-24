"""Tests ItemDetector — détection ECNi via tableau Rang/Rubrique/Intitulé.

Les tests couvrent :
  - Rang depuis les tables pdfplumber et depuis le texte brut "Rang Rubrique …"
  - Délimitation du contenu item (du header jusqu'au header suivant)
  - Filtrage des références inline ("voir item N" dans le corps du texte)
  - Titres d'items (story 8.0)

Chantier 4 : les règles du découpage (R0-R10) et le rapport sont testés dans
tests/services/ocr/test_segmentation_rules.py. Ici, `detect_items` est lu via ses items.
Une page de moins de 40 caractères utiles est blanche (R0) : les pages de test courtes
sont complétées par BODY.
"""

import pytest

from app.services.ocr.item_detector import DetectedItem, ItemDetector

# ── Fixtures détecteur ────────────────────────────────────────────────────────


class _ItemsOnly:
    def detect_items(self, *args, **kwargs) -> list[DetectedItem]:
        return ItemDetector().detect_items(*args, **kwargs).items


@pytest.fixture
def detector():
    return _ItemsOnly()


# Corps de page : au-delà du seuil de page blanche (R0).
BODY = "Texte de cours assez long pour ne pas passer pour une page blanche.\n"


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
PAGE_ITEM_200 = "Item 200\nTitre item 200.\n" + BODY
TABLE_ITEM_200_ONLY_C = [
    ["Rang", "Rubrique", "Intitulé connaissance"],
    ["C", "Spécialité", "Connaître un traitement avancé"],
]

# Page de contenu (pas d'en-tête, pas de table)
PAGE_CONTENT = "I. INTRODUCTION\n\nContenu du cours ici.\n" + BODY

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


# ── Rang depuis les tables pdfplumber et le texte OCR ─────────────────────────


def rang_of(tables=None, text=""):
    """Rang d'un item de 2 pages dont la 1re porte `text` et les tables `tables`."""
    pages = ["Item 75\nTitre\n" + text + BODY, "Item 75\n" + BODY]
    items = ItemDetector().detect_items(pages, page_tables=[tables or [], []]).items
    assert [i.item_number for i in items] == [75]
    return items[0].rang


class TestRangFromTables:
    def test_rang_a_when_a_rows_present(self):
        assert rang_of([TABLE_ITEM_75]) == "A"

    def test_rang_b_when_only_b_rows(self):
        assert rang_of([TABLE_ITEM_110_ONLY_B]) == "B"

    def test_rang_c_is_not_an_objective_rang(self):
        """Chantier 4 : seuls A et B sont des rangs d'objectif ; C → rang inconnu, A par défaut."""
        assert rang_of([TABLE_ITEM_200_ONLY_C]) == "A"

    def test_priority_a_over_b_and_c(self):
        """Table avec A, B, C mélangés → rang A (priorité A > B > C)."""
        table = [
            ["Rang", "Rubrique", "Intitulé"],
            ["B", "Def", "..."],
            ["C", "Spec", "..."],
            ["A", "Étiologie", "..."],
        ]
        assert rang_of([table]) == "A"

    def test_priority_b_over_c(self):
        table = [
            ["Rang", "Rubrique", "Intitulé"],
            ["C", "Spec", "..."],
            ["B", "Def", "..."],
        ]
        assert rang_of([table]) == "B"

    def test_default_a_when_no_rang_column(self):
        table = [["Colonne1", "Colonne2"], ["val1", "val2"]]
        assert rang_of([table]) == "A"

    def test_default_a_when_tables_empty(self):
        assert rang_of([]) == "A"

    def test_handles_none_cells_gracefully(self):
        table = [
            ["Rang", "Rubrique", "Intitulé"],
            [None, "Rubrique1", "..."],
            ["A", "Rubrique2", "..."],
        ]
        assert rang_of([table]) == "A"

    def test_rang_column_case_insensitive(self):
        table = [
            ["RANG", "Rubrique", "Intitulé"],
            ["B", "Def", "..."],
        ]
        assert rang_of([table]) == "B"


class TestRangFromText:
    def test_detects_rang_from_pytesseract_text(self):
        assert rang_of(text="Rang Rubrique Intitulé\nA Définition x\nB Traitement y\n") == "A"

    def test_priority_a_over_b_in_text(self):
        assert rang_of(text="Rang Rubrique Intitulé\nB Définition ...\nA Étiologie ...\n") == "A"

    def test_default_a_without_table(self):
        """Texte sans tableau d'objectifs → rang inconnu, A par défaut (warning au rapport)."""
        assert rang_of(text="Contenu sans tableau.\n") == "A"

    def test_stops_at_section_header(self):
        """Arrêt du parsing quand on atteint une section de contenu (I. INTRODUCTION)."""
        text = "Rang Rubrique Intitulé\nB Définition ...\nI. INTRODUCTION\nA Diagnostic faux rang après section\n"
        # Seulement "B" avant la section, pas "A" après
        assert rang_of(text=text) == "B"


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

    def test_rang_c_item_defaults_to_a(self, detector):
        """Chantier 4 : C n'est pas un rang d'objectif → rang inconnu, A par défaut."""
        items = detector.detect_items([PAGE_ITEM_200], page_tables=[[TABLE_ITEM_200_ONLY_C]])
        assert items[0].rang == "A"

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
        page = "Item n°42\nTitre\n" + BODY
        table = [["Rang", "Rubrique", "Intitulé"], ["A", "Def", "..."]]
        items = detector.detect_items([page], page_tables=[[table]])
        assert items[0].item_number == 42

    def test_item_uppercase(self, detector):
        """Supporte 'ITEM 15' (insensible à la casse)."""
        page = "ITEM 15\nHypertension artérielle.\n" + BODY
        table = [["Rang", "Rubrique", "Intitulé"], ["B", "Def", "..."]]
        items = detector.detect_items([page], page_tables=[[table]])
        assert items[0].item_number == 15

    def test_ocr_text_contains_all_item_pages(self, detector):
        """Le texte OCR de l'item inclut le contenu de toutes ses pages."""
        pages = [PAGE_ITEM_75, "contenu page 1 spécifique\n" + BODY, "contenu page 2 spécifique\n" + BODY]
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
        """En-tête répété sans signal de rang → rang 'A' par défaut.

        Chantier 4 (R4/R5) : un « Item N » isolé sans signal fort n'ouvre plus d'item ;
        l'en-tête est ici répété sur 2 pages (numéro sûr)."""
        page = "Item 99\nTitre sans tableau ni rang dans le texte.\n"
        items = detector.detect_items([page, page], page_tables=[[], []])
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
        page = f"Item 311 {sep} Tumeurs du rein\n" + BODY
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
        # Page d'ouverture (tableau de rang) : un en-tête isolé n'ouvre plus d'item (R5).
        items = detector.detect_items([CNEC_290_P2], page_tables=[[TABLE_SIMPLE_A]])
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
        pages = [
            "Item 299\nIntroduction du chapitre\n" + BODY,
            "Item 299\nOBJECTIFS: N° 299. Tumeurs intracrâniennes\n-+\n",
        ]
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
        pages = ["Item 297\nIntro\n" + BODY, "Item 297\nsuite\n" + BODY]
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
        pages = ["Item 312\nOBJECTIFS: N° 312. Tumeurs du sein\n", ". Item 313\nTumeurs du testicule\n" + BODY]
        # Page d'ouverture de 313 (tableau de rang) : un en-tête isolé n'ouvre plus d'item (R5).
        items = detector.detect_items(pages, page_tables=[[], [TABLE_SIMPLE_A]])
        assert [i.item_number for i in items] == [312, 313]
        assert items[1].chapter_title == "Tumeurs du testicule"

    def test_toc_gives_title_when_no_objectifs(self, detector):
        toc = (
            "SOMMAIRE\n►\n"
            "Chapitre 17 : Tumeurs des os primitives et secondaires .......... 287\nItem 307\n"
            "Chapitre 18 : Tumeurs du pancréas ...............................\n307\nItem 308\n"
            "C' a ire 13 : Tumeurs de l'estomac ................ 213\nItem 303\n"
        )
        pages = [toc, "Item 308\n1.2. Facteurs de risque\n" + BODY, "Item 308\nN - Adénopathies régionales\n" + BODY]
        items = detector.detect_items(pages, page_tables=[[], [], []])
        assert [i.item_number for i in items] == [308]
        assert items[0].chapter_title == "Tumeurs du pancréas"

    def test_header_title_read_on_first_page_only(self, detector):
        pages = ["Item 308\n1.2. Facteurs de risque\n" + BODY, "Item 308\nN - Adénopathies régionales\n" + BODY]
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
        pages = [
            "Item 306\nTumeurs de l'ovaire\n" + BODY,
            "tem 30\nClinique\n" + BODY,
            "Item 306\n4. Démarche\n" + BODY,
        ]
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
        # « Introduction » seule en 2e ligne avant le 1er item serait une section liminaire (R7 bis).
        pages = ["Item 290\nGénéralités\n" + BODY, "Item 290\nÉpidémiologie\n" + BODY]
        items = detector.detect_items(pages, page_tables=[[], []])
        assert items[0].chapter_title == ""

    def test_related_items_list_does_not_make_header_a_toc(self, detector):
        page = "Item 75\nAddiction au tabac.\nItems liés :\n- Item 12\n- Item 45\n• Item 46\n"
        page_76 = "Item 76\nTitre suivant correct\n" + BODY
        items = detector.detect_items([page, page_76], page_tables=[[TABLE_ITEM_75], [TABLE_SIMPLE_A]])
        assert [i.item_number for i in items] == [75, 76]
        assert items[0].chapter_title == "Addiction au tabac"

    def test_bulleted_reference_is_not_a_header(self, detector):
        pages = [PAGE_ITEM_75, "• Item 230 évoqué ici\nsuite du texte\n" + BODY]
        items = detector.detect_items(pages, page_tables=[[TABLE_ITEM_75], []])
        assert [(i.item_number, i.start_page, i.end_page) for i in items] == [(75, 0, 1)]

    def test_toc_with_title_below_number_is_ignored(self, detector):
        """Sommaire « Item N \\n Titre » : le tampon serait décalé d'un rang → rejeté."""
        toc = (
            "SOMMAIRE\nItem 306\nTumeurs du col utérin ...... 12\n"
            "Item 307\nTumeurs de l'ovaire ...... 30\nItem 308\nTumeurs du pancréas ...... 44\n"
        )
        pages = [toc, "Item 307\nTumeurs de l'ovaire\n" + BODY]
        items = detector.detect_items(pages, page_tables=[[], [TABLE_SIMPLE_A]])
        assert items[0].chapter_title == "Tumeurs de l'ovaire"

    def test_non_adjacent_repeat_keeps_header_title(self, detector):
        """CEP : « Item 359 bis » 14 pages plus loin n'est pas un en-tête courant."""
        pages = [
            "Item 359\nDétresse respiratoire de l’adulte\nRang Rubrique\n",
            "suite\n" + BODY,
            "Item 359 bis\nDétresse de l'enfant\n" + BODY,
        ]
        items = detector.detect_items(pages, page_tables=[[TABLE_SIMPLE_A], [], []])
        assert items[0].chapter_title == "Détresse respiratoire de l’adulte"
