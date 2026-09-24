"""Extraction du texte : caractères pivotés dans le bon ordre, lettres doublées (chantier 4, spec § 4)."""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

import pytest

from app.services.ocr.ocr_processor import OcrProcessor
from app.services.ocr.text_normalize import undouble

REPO_ROOT = Path(__file__).resolve().parents[4]
HEMATO_PDF = REPO_ROOT / "HEMATO 5e college.pdf"

PARAGRAPHE = "Transfusion sanguine et produits sanguins labiles : principes generaux."


def _pdf_pivote(path: Path, angle: int) -> Path:
    """PDF d'une page : un paragraphe droit et « Indications » tourné de `angle` degrés."""
    from reportlab.pdfgen import canvas

    c = canvas.Canvas(str(path), pagesize=(595, 842))
    c.setFont("Helvetica", 11)
    c.drawString(50, 780, PARAGRAPHE)
    c.saveState()
    c.translate(300, 400)
    c.rotate(angle)
    c.drawString(0, 0, "Indications")
    c.restoreState()
    c.save()
    return path


class TestTextePivote:
    @pytest.mark.parametrize("angle", [90, -90], ids=["anti-horaire", "horaire"])
    def test_mot_pivote_lu_dans_le_bon_sens(self, tmp_path, angle):
        pdf = _pdf_pivote(tmp_path / f"pivote_{angle}.pdf", angle)

        result = OcrProcessor().process_page(pdf, 0)

        assert result.method == "pdfplumber"
        assert "Indications" in result.text
        assert "snoitacidnI" not in result.text
        # le texte droit reste en tête, intact
        assert result.text.splitlines()[0] == PARAGRAPHE

    def test_interface_inchangee(self, tmp_path):
        pdf = _pdf_pivote(tmp_path / "pivote.pdf", 90)
        processor = OcrProcessor()

        result = processor.process_page(pdf, 0)

        assert processor.count_pages(pdf) == 1
        assert result.page_num == 0
        assert 0.0 < result.confidence_score <= 1.0
        assert isinstance(result.tables, list)


class TestUndouble:
    def test_ligne_doublee(self):
        assert undouble("TTuummeeuurrss") == "Tumeurs"
        assert undouble("TTaabbllee  ddeess  mmaattiièèrreess") == "Table des matières"

    def test_ligne_normale_inchangee(self):
        ligne = "Anémie ferriprive : diagnostic et traitement"
        assert undouble(ligne) == ligne

    def test_college_inchange(self):
        assert undouble("Collège") == "Collège"

    def test_ligne_courte_inchangee(self):
        assert undouble("AAbb") == "AAbb"

    def test_ligne_sans_lettre_inchangee(self):
        # points de conduite d'un sommaire : ne pas les raccourcir
        assert undouble("............") == "............"

    def test_idempotent(self):
        once = undouble("CCoollllèèggee")
        assert once == "Collège"
        assert undouble(once) == once

    def test_applique_ligne_par_ligne_a_l_extraction(self, tmp_path):
        from reportlab.pdfgen import canvas

        path = tmp_path / "double.pdf"
        c = canvas.Canvas(str(path), pagesize=(595, 842))
        c.setFont("Helvetica", 11)
        c.drawString(50, 780, "TTUUMMEEUURRSS")
        c.drawString(50, 760, PARAGRAPHE)
        c.save()

        result = OcrProcessor().process_page(path, 0)

        assert result.text.splitlines() == ["TUMEURS", PARAGRAPHE]


def _mots(texte: str) -> list[str]:
    return [w.lower() for w in re.findall(r"[A-Za-zÀ-ÿ]{5,}", texte)]


@pytest.mark.skipif(not HEMATO_PDF.exists(), reason="PDF réel absent (hors git)")
def test_hemato_page_385_sans_mot_a_l_envers():
    """Tableau pivoté des PSL (item 329) : aucun mot dont l'inverse est fréquent autour."""
    import pdfplumber

    processor = OcrProcessor()
    pages = range(381, 392)
    textes = {n: processor.process_page(HEMATO_PDF, n).text for n in pages}
    vocab = Counter(w for t in textes.values() for w in _mots(t))

    def a_l_envers(texte: str) -> int:
        return sum(1 for w in _mots(texte) if vocab[w] <= 1 and vocab[w[::-1]] >= 2)

    with pdfplumber.open(str(HEMATO_PDF)) as pdf:
        avant = pdf.pages[385].extract_text() or ""
    assert a_l_envers(avant) > 50  # le test mesure bien le défaut d'origine
    assert a_l_envers(textes[385]) == 0
