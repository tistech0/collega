"""Découpage des items (chantier 4, spec § 4) : un test synthétique par règle R0-R10,
plus le rang par objectif (pictogrammes, colonne de rang trouvée par ses valeurs).

Les pages sont écrites à la main ; aucun texte de collège réel.
"""

import json

import pytest

from app.services.ocr.item_detector import (
    ItemDetector,
    SegmentationResult,
    header_candidates,
    page_lines,
    segmentation_overview,
)

# Corps de page : assez long pour ne pas être une page blanche (R0 : < 40 caractères utiles).
BODY = "Texte de cours assez long pour ne pas passer pour une page blanche."


def page(*lines: str) -> str:
    return "\n".join([*lines, BODY])


def seg(pages: list[str], **kwargs) -> SegmentationResult:
    return ItemDetector().detect_items(pages, **kwargs)


def spans(result: SegmentationResult) -> list[tuple[int, int, int]]:
    return [(i.item_number, i.start_page, i.end_page) for i in result.items]


def kinds(result: SegmentationResult) -> list[tuple[str, int | str | None]]:
    return [(p.kind, p.item_number if p.kind == "item" else p.label) for p in result.report.pages]


# ── R0 : normalisation ────────────────────────────────────────────────────────


class TestR0Normalisation:
    def test_watermark_only_page_is_blank(self):
        result = seg(["Pour avoir plus d'exclusivités rejoindre nous sur www.amis-med.com\n"])
        assert kinds(result) == [("blank", None)]
        assert result.items == []

    def test_short_page_is_blank(self):
        assert kinds(seg(["Fig. 3\n12\n"])) == [("blank", None)]

    def test_doubled_letters_are_undoubled(self):
        assert page_lines("TTuummeeuurrss  dduu  ppaannccrrééaass\n") == ["Tumeurs du pancréas"]

    def test_watermark_lines_are_dropped(self):
        text = "Item 290\nIl a été diffusé exclusivement et gratuitement sur le forum © SBA-MEDECINE\nsuite"
        assert page_lines(text) == ["Item 290", "suite"]


# ── R1 : en-tête « Item N » ───────────────────────────────────────────────────


class TestR1Header:
    @pytest.mark.parametrize(
        ("line", "expected"),
        [
            ("Item 21 2 - Hémogramme", [212, 21]),
            ("Item 3 1 5", [315, 3]),
            ("• em 299", [299]),
            ("tem 300", [300]),
            ("w Item 214", [214]),
            ("- / Item 330", [330]),
            ("Item 359 bis", [359]),
            ("Item n°42", [42]),
            ("ITEM 15", [15]),
            (". Item 313", [313]),
            ("voir Item 42", []),
            ("Items liés", []),
        ],
    )
    def test_header_candidates(self, line, expected):
        assert header_candidates(line) == expected

    def test_header_only_in_first_five_lines(self):
        lines = [f"ligne de cours numéro {n} avec du texte" for n in range(11)]
        result = seg([page(*lines, "Item 42 - Titre")])
        assert not any(s.startswith("en-tête") for s in result.report.pages[0].signals)


# ── R2 : OBJECTIFS ouvre l'item ───────────────────────────────────────────────


class TestR2Objectifs:
    def test_objectifs_opens_item_without_readable_header(self):
        pages = [
            page("Item 299", "OBJECTIFS: N° 299. Tumeurs intracrâniennes"),
            page("Item 299", "suite du chapitre"),
            page("em 30", 'OBJECTIFS: N"o300. Tumeurs du col utérin'),
            page("Item 300", "suite"),
        ]
        assert spans(seg(pages)) == [(299, 0, 1), (300, 2, 3)]


# ── R3 : page d'ouverture ─────────────────────────────────────────────────────


class TestR3Opening:
    def test_chapter_page_opens_item_despite_running_header(self):
        pages = [
            page("CHAPITRE", "14", "Item 218", "Hémophilie"),
            page("Item 21 8 - Hémophilie"),
            page("CHAPITRE", "15", "w Item 214", "Thrombopénie"),
            page("Connaissances"),
        ]
        assert spans(seg(pages)) == [(218, 0, 1), (214, 2, 3)]

    def test_cep_first_line_opens_item(self):
        pages = [
            page("Collège des Enseignants de Pneumologie - 2023", "Item 75", "Addiction au tabac"),
            page("2/12"),
            page("Collège des Enseignants de Pneumologie - 2023", "Item 110", "Sommeil"),
        ]
        assert spans(seg(pages)) == [(75, 0, 1), (110, 2, 2)]

    def test_rang_table_in_text_or_pdfplumber_opens_item(self):
        pages = [page("Item 75", "Rang Rubrique Intitulé"), page("suite"), page("Item 110", "Titre")]
        tables = [[], [], [[["Rang", "Rubrique", "Intitulé"], ["A", "Définition", "x"]]]]
        assert spans(seg(pages, page_tables=tables)) == [(75, 0, 1), (110, 2, 2)]


# ── R4 : numéros sûrs (K) et résolution des en-têtes coupés ──────────────────


class TestR4KnownNumbers:
    def test_split_and_truncated_headers_resolve_to_current(self):
        pages = [
            page("CHAPITRE", "2", "Item 212", "Hémogramme"),
            page("Item 21 2 - Hémogramme"),
            page("Item 21 - Hémogramme"),
            page("CHAPITRE", "3", "Item 213", "Anémie"),
        ]
        result = seg(pages)
        assert spans(result) == [(212, 0, 2), (213, 3, 3)]
        assert not [i for i in result.items if i.item_number == 21]

    def test_truncated_repeated_header_is_not_a_known_number(self):
        """« em 29 » ×2 n'entre pas dans K : c'est le préfixe de 298 (sûr)."""
        pages = [
            page("Item 298", "OBJECTIFS : N° 298. Tumeurs de la cavité buccale"),
            page("em 29"),
            page("em 29"),
            page("Item 298"),
        ]
        assert spans(seg(pages)) == [(298, 0, 3)]

    def test_number_outside_official_referential_never_enters_k(self):
        pages = [
            page("Item 290", "OBJECTIFS: N° 290. Épidémiologie des cancers"),
            page("Item 999"),
            page("Item 999"),
        ]
        official = {n: f"Titre officiel {n}" for n in range(1, 368)}
        assert spans(seg(pages, known_titles=official)) == [(290, 0, 2)]
        # Sans référentiel, le numéro répété entre dans K.
        assert spans(seg(pages)) == [(290, 0, 0), (999, 1, 2)]
        # Référentiel partiel (quelques titres posés à la main) : pas de restriction.
        assert spans(seg(pages, known_titles={290: "Épidémiologie des cancers"})) == [(290, 0, 0), (999, 1, 2)]


# ── R5 : en-tête courant ≠ item courant ───────────────────────────────────────


class TestR5WeakHeader:
    def test_unknown_isolated_header_does_not_open(self):
        pages = [
            page("Item 290", "OBJECTIFS: N° 290. Épidémiologie des cancers"),
            page("Item 290"),
            page("Item 21"),
            page("Item 290"),
        ]
        result = seg(pages)
        assert spans(result) == [(290, 0, 3)]
        assert any("p2" in w and "ignoré" in w for w in result.report.warnings)

    def test_confirmed_known_header_opens_at_its_first_page(self):
        pages = [
            page("Item 290", "OBJECTIFS: N° 290. Épidémiologie des cancers"),
            page("Item 290"),
            page("Item 291"),
            page("Tableau sans en-tête"),
            page("Item 291"),
        ]
        assert spans(seg(pages)) == [(290, 0, 1), (291, 2, 4)]

    def test_known_but_unconfirmed_header_does_not_open(self):
        toc = "SOMMAIRE\nItem 290 ....... 12\nItem 291 ....... 26\nItem 292 ....... 44\n"
        pages = [
            toc,
            page("Item 290", "OBJECTIFS: N° 290. Épidémiologie des cancers"),
            page("Item 291"),
            page("x " * 30),
        ]
        assert spans(seg(pages)) == [(290, 1, 3)]


# ── R6 : ouverture par titre connu ────────────────────────────────────────────


class TestR6TitleOpening:
    TOC = "SOMMAIRE\nItem 316 ....... 118\nItem 317 ....... 132\nItem 318 ....... 150\n"

    def pages(self):
        return [
            self.TOC,
            page("CHAPITRE", "5", "Item 316", "Syndromes myélodysplasiques"),
            page("Item 316 - Syndromes myélodysplasiques"),
            page("Syndromes", "myéloprolifératifs", "I. Introduction"),
            page("Item 317 - Syndromes myéloprolifératifs"),
        ]

    def test_known_title_opens_item(self):
        result = seg(self.pages(), known_titles={317: "Syndromes myéloprolifératifs"})
        assert spans(result) == [(316, 1, 2), (317, 3, 4)]
        assert "titre:317" in result.report.pages[3].signals

    def test_toc_title_opens_item_without_referential(self):
        pages = self.pages()
        pages[0] = (
            "SOMMAIRE\n5 Item 316 - Syndromes myélodysplasiques 118\n6 Item 317 - Syndromes myéloprolifératifs 132\n"
        )
        pages[0] += "7 Item 318 - Autre 150\n"
        assert spans(seg(pages)) == [(316, 1, 2), (317, 3, 4)]

    def test_doubled_title_opens_item(self):
        pages = self.pages()
        pages[3] = page("SSyynnddrroommeess  mmyyéélloopprroolliifféérraattiiffss", "I. Introduction")
        assert spans(seg(pages, known_titles={317: "Syndromes myéloprolifératifs"})) == [(316, 1, 2), (317, 3, 4)]


# ── R7 : sections hors item ───────────────────────────────────────────────────


class TestR7Sections:
    def test_end_sections_close_item(self):
        pages = [
            page("CHAPITRE", "23", "Item 329", "Transfusion"),
            page("Item 329 - Transfusion"),
            page("CHAPITRE", "24", "Dossiers progressifs"),
            page("Entraînement"),
        ]
        result = seg(pages)
        assert spans(result) == [(329, 0, 1)]
        assert kinds(result)[2:] == [("section", "dossiers progressifs")] * 2

    def test_chapter_without_item_is_a_section(self):
        pages = [page("CHAPITRE", "1", "Hématopoïèse"), page("suite du chapitre 1"), page("CHAPITRE", "2", "Item 212")]
        result = seg(pages)
        assert spans(result) == [(212, 2, 2)]
        assert kinds(result)[:2] == [("section", "chapitre sans item")] * 2

    def test_front_matter_before_first_item(self):
        pages = [
            "SOMMAIRE\nItem 290 ..... 12\nItem 291 ..... 26\nItem 292 ..... 44\n",
            page("Préface"),
            page("Les auteurs"),
            page("Item 290", "OBJECTIFS: N° 290. Épidémiologie des cancers"),
        ]
        result = seg(pages)
        assert [k for k, _ in kinds(result)] == ["section", "section", "section", "item"]
        assert [label for _, label in kinds(result)[:3]] == ["sommaire", "préface", "auteurs"]

    def test_introduction_inside_item_stays_in_item(self):
        """R7 bis : après le 1er item, « INTRODUCTION » est un intertitre."""
        pages = [
            page("Collège des Enseignants de Pneumologie - 2023", "Item 110", "Sommeil"),
            page("INTRODUCTION"),
            page("Suite"),
        ]
        assert spans(seg(pages)) == [(110, 0, 2)]


# ── R8 : un item par numéro ───────────────────────────────────────────────────


class TestR8OneItemPerNumber:
    def test_consecutive_chapters_of_same_item_form_one_item(self):
        pages = [
            page("CHAPITRE", "18", "Item 216", "Hémostase"),
            page("Item 216 - Hémostase"),
            page("CHAPITRE", "19", "Item 216", "Thromboses"),
            page("Item 216 - Thromboses"),
        ]
        result = seg(pages)
        assert spans(result) == [(216, 0, 3)]
        assert not any("réouverture" in w for w in result.report.warnings)

    def test_weak_header_does_not_reopen_closed_item(self):
        pages = [
            page("Item 290", "OBJECTIFS: N° 290. Épidémiologie"),
            page("Item 290"),
            page("Item 291", "OBJECTIFS: N° 291. Cancérogenèse"),
            page("Item 290"),
            page("Item 290"),
        ]
        assert spans(seg(pages)) == [(290, 0, 1), (291, 2, 4)]

    def test_strong_reopening_concatenates_pages_with_warning(self):
        pages = [
            page("CHAPITRE", "18", "Item 216"),
            page("Item 216 - Hémostase"),
            page("CHAPITRE", "19", "Item 217"),
            page("Item 217 - Autre"),
            page("CHAPITRE", "20", "Item 216"),
        ]
        result = seg(pages)
        by_number = {i.item_number: i for i in result.items}
        assert sorted(by_number) == [216, 217]
        assert by_number[216].pages == [0, 1, 4]
        assert (by_number[216].start_page, by_number[216].end_page) == (0, 4)
        assert BODY in by_number[216].ocr_text
        assert any("réouverture" in w and "216" in w for w in result.report.warnings)


# ── R9 : pages blanches neutres ───────────────────────────────────────────────


class TestR9BlankPages:
    def test_item_ends_at_last_content_page(self):
        pages = [
            page("Item 298", "OBJECTIFS: N° 298. Tumeurs ORL"),
            page("Item 298"),
            "",
            page("Item 299", "OBJECTIFS: N° 299. Tumeurs intracrâniennes"),
        ]
        result = seg(pages)
        assert spans(result) == [(298, 0, 1), (299, 3, 3)]
        assert kinds(result)[2] == ("blank", None)

    def test_blank_page_inside_item_stays(self):
        pages = [page("Item 298", "OBJECTIFS: N° 298. Tumeurs ORL"), "", page("Item 298")]
        result = seg(pages)
        assert spans(result) == [(298, 0, 2)]
        assert result.items[0].pages == [0, 1, 2]


# ── R10 : rapport de découpage ────────────────────────────────────────────────


class TestR10Report:
    def test_every_page_once_content_before_first_item_is_front_matter(self):
        pages = [page("Texte sans en-tête avant tout item"), page("Item 290", "OBJECTIFS: N° 290. Épidémiologie"), ""]
        result = seg(pages)
        assert [p.page for p in result.report.pages] == [0, 1, 2]
        assert kinds(result) == [("section", "liminaire"), ("item", 290), ("blank", None)]

    def test_report_is_json_without_page_text(self):
        pages = [page("Item 290", "OBJECTIFS: N° 290. Épidémiologie"), page("Item 290"), page("CHAPITRE", "2", "Index")]
        report = seg(pages).report
        data = json.loads(report.to_json())
        assert data["items"][0]["item_number"] == 290 and data["items"][0]["pages"] == "0-1"
        assert data["sections"] == [{"label": "chapitre sans item", "pages": "2"}]
        assert data["pages"][0] == {
            "page": 0,
            "kind": "item",
            "item_number": 290,
            "signals": ["en-tête:290", "objectifs:290"],
        }
        assert "Texte de cours" not in report.to_json() and "Épidémiologie" not in report.to_json()
        assert "1 items" in report.summary() and "Texte" not in report.summary()

    def test_overview_for_admin_drops_page_detail(self):
        report = seg([page("Item 290", "OBJECTIFS: N° 290. Épidémiologie"), page("Item 290")]).report
        overview = segmentation_overview(report.to_json())
        assert overview is not None and "pages" not in overview
        assert overview["items"][0]["pages"] == "0-1"
        assert segmentation_overview(None) is None
        assert segmentation_overview("{pas du json") is None

    def test_short_item_warning(self):
        result = seg([page("Item 75", "Rang Rubrique Intitulé", "A Définition Connaître")])
        assert any("item 75" in w and "moins de 2 pages" in w for w in result.report.warnings)


# ── Rang par objectif (§ 3) ───────────────────────────────────────────────────


def ranked(*table_lines: str, tables=None, extra_pages: list[str] | None = None):
    pages = [page("Item 75", "Rang Rubrique Intitulé", *table_lines), *(extra_pages or [page("Item 75")])]
    return seg(pages, page_tables=tables).items[0]


class TestObjectiveRang:
    def test_letters(self):
        item = ranked("A Définition Connaître", "B Diagnostic Savoir", "A* Prise en charge Savoir")
        assert (item.rang, item.objectives_a, item.objectives_b) == ("A", 2, 1)

    @pytest.mark.parametrize("glyph", ["O", "0", "G", "©", "@", "A*"])
    def test_black_glyphs_are_rang_a(self, glyph):
        item = ranked(f"{glyph} Définition Connaître", "Q Diagnostic Savoir")
        assert (item.rang, item.objectives_a, item.objectives_b) == ("A", 1, 1)

    @pytest.mark.parametrize("glyph", ["Q", "□", "s", "B*"])
    def test_blue_glyphs_are_rang_b(self, glyph):
        item = ranked(f"{glyph} Définition Connaître")
        assert (item.rang, item.objectives_a, item.objectives_b) == ("B", 0, 1)

    def test_unknown_glyphs_give_default_a_with_warning(self):
        pages = [
            page("Item 75", "Rang Rubrique Intitulé", "3 Définition Connaître", "IB Diagnostic x"),
            page("Item 75"),
        ]
        result = seg(pages)
        assert (result.items[0].rang, result.items[0].objectives_a, result.items[0].objectives_b) == ("A", 0, 0)
        assert any("item 75" in w and "rang inconnu" in w for w in result.report.warnings)

    def test_header_with_ocr_underscores(self):
        pages = [page("Item 290", "OBJECTIFS: N° 290. Épidémiologie", "Rang__ Rubrique Intitulé", "B Définition x")]
        pages.append(page("Item 290"))
        assert seg(pages).items[0].objectives_b == 1

    @pytest.mark.parametrize(
        "header",
        ["Rang__ Rubrique Intitulé", "Ra~g Rubrique T Intitulé", "1 Rang j Rubrique Intitulé", "~ Rubrique Intitulé"],
    )
    def test_ocr_damaged_table_header(self, header):
        pages = [page("Item 290", "OBJECTIFS: N° 290. Épidémiologie", header, "A Définition x"), page("Item 290")]
        assert seg(pages).items[0].objectives_a == 1

    def test_rubrique_in_body_text_is_not_a_table_header(self):
        line = "Cette longue phrase du cours cite la rubrique sans être un tableau"
        pages = [page("Item 290", "OBJECTIFS: N° 290. Épidémiologie", line), page("Item 290")]
        assert any("item 290" in w and "sans tableau" in w for w in seg(pages).report.warnings)
        pages[0] = page("Item 290", "OBJECTIFS: N° 290. Épidémiologie", "Rang Rubrique Intitulé")
        assert any("item 290" in w and "aucun objectif" in w for w in seg(pages).report.warnings)

    def test_table_continues_on_next_two_pages_only(self):
        pages = [
            page("Item 75", "Rang Rubrique Intitulé", "A Définition Connaître"),
            page("Item 75", "B Diagnostic Savoir"),
            page("Item 75", "B Traitement Savoir"),
            page("Item 75", "A Définition hors du tableau d'objectifs"),
        ]
        item = seg(pages).items[0]
        assert (item.objectives_a, item.objectives_b) == (1, 2)

    def test_rows_without_table_header_count_known_glyphs_only(self):
        """En-tête du tableau perdu à l'OCR : seules les lignes à pictogramme connu comptent."""
        pages = [page("Item 75", "A Définition x", "Q Diagnostic y", "3 Traitement z"), page("Item 75")]
        item = seg(pages).items[0]
        assert (item.objectives_a, item.objectives_b) == (1, 1)

    def test_table_ends_at_first_course_section(self):
        pages = [page("Item 75", "Rang Rubrique Intitulé", "B Diagnostic x", "I. Introduction", "A Définition y")]
        item = seg([*pages, page("Item 75")]).items[0]
        assert (item.objectives_a, item.objectives_b) == (0, 1)

    def test_pdfplumber_rang_column_found_by_values(self):
        """CEP : en-tête « Rang » en colonne 1, valeurs A/B en colonne 0 (cellules fusionnées)."""
        table = [
            [None, "Rang", "Rubrique", "Intitulé"],
            ["A", None, "Définition", "Connaître"],
            ["A", None, "Diagnostic", "Savoir"],
            ["B", None, "Traitement", "Savoir"],
        ]
        pages = [page("Item 75", "Addiction au tabac"), page("Item 75")]
        item = seg(pages, page_tables=[[table], []]).items[0]
        assert (item.rang, item.objectives_a, item.objectives_b) == ("A", 2, 1)

    def test_table_without_rang_values_is_ignored(self):
        table = [["Colonne", "Valeur"], ["x", "12"], ["y", "13"]]
        pages = [page("Item 75", "Rang Rubrique Intitulé", "B Définition x"), page("Item 75")]
        item = seg(pages, page_tables=[[table], []]).items[0]
        assert (item.rang, item.objectives_a, item.objectives_b) == ("B", 0, 1)

    def test_rang_c_is_not_counted(self):
        table = [["Rang", "Rubrique", "Intitulé"], ["C", "Spécialité", "x"]]
        pages = [page("Item 200", "Titre"), page("Item 200")]
        result = seg(pages, page_tables=[[table], []])
        assert (result.items[0].rang, result.items[0].objectives_a, result.items[0].objectives_b) == ("A", 0, 0)
        assert any("rang inconnu" in w for w in result.report.warnings)
