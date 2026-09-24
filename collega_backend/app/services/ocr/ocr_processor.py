"""OCR processor: pdfplumber (texte natif) avec fallback pytesseract (pages image)."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from app.services.ocr.text_normalize import undouble_text

logger = logging.getLogger(__name__)

# Type alias pour la lisibilité
PageTables = list[list[list[str]]]  # list[table], table = list[row], row = list[cell]


@dataclass
class OcrPageResult:
    page_num: int
    text: str
    confidence_score: float
    method: str  # "pdfplumber" | "pytesseract" | "empty"
    word_confidences: list[float] = field(default_factory=list)
    tables: PageTables = field(default_factory=list)  # tableaux extraits par pdfplumber


class OcrProcessor:
    """Extrait le texte d'une page PDF avec calcul de score de confiance.

    Stratégie : pdfplumber pour les PDFs natifs texte, pytesseract en fallback
    pour les pages image/scan. Les imports sont lazily évalués pour ne pas
    bloquer le démarrage si les libs sont absentes du conteneur de dev.
    """

    MIN_TEXT_LENGTH = 50  # Seuil en caractères pour considérer qu'une page a du texte

    def process_page(self, pdf_path: str | Path, page_num: int) -> OcrPageResult:
        """Traite une page et retourne le texte avec son score de confiance (0.0–1.0)."""
        try:
            result = self._extract_with_pdfplumber(pdf_path, page_num)
            if result is not None and len(result.text.strip()) >= self.MIN_TEXT_LENGTH:
                return result
        except Exception as exc:  # noqa: BLE001
            logger.warning("pdfplumber failed on page %d: %s", page_num, exc)

        # Fallback : pytesseract sur image
        try:
            return self._extract_with_pytesseract(pdf_path, page_num)
        except Exception as exc:  # noqa: BLE001
            logger.warning("pytesseract failed on page %d: %s", page_num, exc)
            return OcrPageResult(
                page_num=page_num,
                text="",
                confidence_score=0.0,
                method="empty",
            )

    def _extract_with_pdfplumber(self, pdf_path: str | Path, page_num: int) -> OcrPageResult | None:
        import pdfplumber  # type: ignore[import]

        with pdfplumber.open(str(pdf_path)) as pdf:
            if page_num >= len(pdf.pages):
                return None
            # Glyphes superposés en double (ex. « CCoollllèèggee » en pneumo) retirés d'abord
            page = pdf.pages[page_num].dedupe_chars()
            text = undouble_text(self._page_text(page))
            words = page.extract_words() or []
            raw_tables = page.extract_tables() or []

        # Normaliser les cellules None → ""
        tables: PageTables = [
            [[cell if cell is not None else "" for cell in row] for row in table] for table in raw_tables
        ]

        score = self._pdfplumber_confidence(text, words)
        return OcrPageResult(
            page_num=page_num,
            text=text,
            confidence_score=score,
            method="pdfplumber",
            tables=tables,
        )

    @staticmethod
    def _page_text(page: Any) -> str:
        """Texte droit, puis caractères pivotés extraits à part dans le bon ordre.

        Par défaut, pdfplumber lit un mot tourné de 90° comme une pile de lignes
        d'un caractère, à l'envers (« snoitacidnI »). La matrice de chaque
        caractère donne le sens : `matrix[1] > 0` → tourné anti-horaire (se lit
        de bas en haut), `matrix[1] < 0` → tourné horaire (de haut en bas).
        Le bloc pivoté est ajouté après le texte droit.
        """

        def is_char(obj: dict[str, Any]) -> bool:
            return bool(obj.get("object_type") == "char")

        def rotation(obj: dict[str, Any]) -> int:
            """1 = anti-horaire, -1 = horaire, 0 = droit (ou penché sans sens de lecture sûr)."""
            if not is_char(obj) or obj.get("upright", True):
                return 0
            b = obj["matrix"][1]
            return (b > 0) - (b < 0)

        parts = [page.filter(lambda o: rotation(o) == 0).extract_text() or ""]
        ccw = page.filter(lambda o: rotation(o) == 1)
        cw = page.filter(lambda o: rotation(o) == -1)
        if ccw.chars:
            parts.append(ccw.extract_text(line_dir_rotated="ltr", char_dir_rotated="btt") or "")
        if cw.chars:
            parts.append(cw.extract_text(line_dir_rotated="rtl", char_dir_rotated="ttb") or "")
        return "\n".join(p for p in parts if p)

    def _extract_with_pytesseract(self, pdf_path: str | Path, page_num: int) -> OcrPageResult:
        import pytesseract  # type: ignore[import]
        from pdf2image import convert_from_path  # type: ignore[import]

        images = convert_from_path(
            str(pdf_path),
            first_page=page_num + 1,
            last_page=page_num + 1,
            dpi=300,
        )
        if not images:
            return OcrPageResult(page_num=page_num, text="", confidence_score=0.0, method="empty")

        image = images[0]
        try:
            data = pytesseract.image_to_data(
                image,
                lang="fra",
                output_type=pytesseract.Output.DICT,
            )
            text = pytesseract.image_to_string(image, lang="fra")
        finally:
            image.close()

        word_confidences = [
            c / 100.0 for c, w in zip(data["conf"], data["text"], strict=False) if int(c) > 0 and w.strip()
        ]
        score = sum(word_confidences) / len(word_confidences) if word_confidences else 0.0
        # pytesseract ne fournit pas de tables structurées — tables reste vide
        return OcrPageResult(
            page_num=page_num,
            text=text,
            confidence_score=score,
            method="pytesseract",
            word_confidences=word_confidences,
        )

    @staticmethod
    def _pdfplumber_confidence(text: str, words: list) -> float:
        """Estime la confiance à partir du ratio de mots détectés sur le texte total."""
        if not text.strip():
            return 0.0
        word_char_count = sum(len(w.get("text", "")) for w in words)
        total_chars = len(text.replace(" ", "").replace("\n", ""))
        if total_chars == 0:
            return 0.0
        ratio = min(word_char_count / total_chars, 1.0)
        return round(0.95 * ratio, 4)

    def count_pages(self, pdf_path: str | Path) -> int:
        """Retourne le nombre total de pages du PDF."""
        import pdfplumber  # type: ignore[import]

        with pdfplumber.open(str(pdf_path)) as pdf:
            return len(pdf.pages)
