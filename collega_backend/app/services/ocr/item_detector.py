"""Détection des items ECNi et de leurs rangs dans le texte OCR.

Structure réelle des PDFs ECNi (collèges CNCEM, COFER, CEP, etc.) :
  - Chaque item débute par une page d'en-tête :
        "Item N\nTitre de l'item"
    suivie d'un tableau structuré :
        Rang | Rubrique | Intitulé connaissance
  - Les pages suivantes contiennent le texte de l'item (sections I, II, …)
    jusqu'à la prochaine page d'en-tête.
  - Le rang de l'item est déterminé d'après ce tableau selon la priorité A > B > C :
    rang "A" si au moins un objectif Rang A existe, sinon "B", sinon "C".

Stratégie de détection du rang (par ordre de priorité) :
  1. Tableau pdfplumber : colonne "Rang" dans les tables extraites de la page.
  2. Texte brut OCR : recherche du bloc tableau "Rang | Rubrique" + lignes "A/B/C …"
     (fallback pour pages scannées via pytesseract).
  3. Défaut "A" avec warning si aucun signal trouvé.
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Literal

logger = logging.getLogger(__name__)

# Pattern item : "Item 75", "Item n°110", "ITEM 330"
# Ancré en début de ligne (re.MULTILINE) pour ne pas matcher "voir item 42" mid-sentence.
_ITEM_HEADER_PATTERN = re.compile(
    r"^item\s*n?°?\s*(\d{1,3})\b", re.IGNORECASE | re.MULTILINE
)
_CHAPTER_PATTERN = re.compile(
    r"(?:chapitre|partie)\s+(.{3,80}?)(?:\n|$)", re.IGNORECASE
)

_RANG_VALID = frozenset({"A", "B", "C"})
# Priorité : A (0) > B (1) > C (2) — l'élément de plus petit index est retenu
_RANG_PRIORITY: dict[str, int] = {"A": 0, "B": 1, "C": 2}

RangType = Literal["A", "B", "C"]

# Position maximale (en caractères) d'un "Item N" dans la page pour être considéré
# comme en-tête d'item (et non une référence inline dans le corps du texte).
_MAX_HEADER_POSITION = 400

PageTables = list[list[list[str]]]  # list[table] → table = list[row] → row = list[cell]


@dataclass
class DetectedItem:
    item_number: int
    rang: RangType
    chapter_title: str
    ocr_text: str
    start_page: int
    end_page: int
    ocr_confidence_score: float
    word_confidences: list[float] = field(default_factory=list)


class ItemDetector:
    """Détecte les items ECNi en exploitant le tableau rang/rubrique/intitulé.

    Approche en deux passes :
      1. Identifier les pages d'en-tête d'item (Item N + tableau rang).
      2. Délimiter le contenu de chaque item (du header jusqu'au header suivant - 1).
    """

    def detect_items(
        self,
        page_texts: list[str],
        page_scores: list[float] | None = None,
        page_tables: list[PageTables] | None = None,
    ) -> list[DetectedItem]:
        """Extrait les items depuis les textes paginés.

        Args:
            page_texts:   texte extrait par page (index = numéro de page).
            page_scores:  score de confiance par page (même longueur que page_texts).
            page_tables:  tables extraites par page par pdfplumber. Chaque élément est
                          la liste des tables d'une page (list[table], table = list[row],
                          row = list[str]). Fourni par OcrProcessor.
        """
        if page_scores is None:
            page_scores = [0.9] * len(page_texts)
        if page_tables is None:
            page_tables = [[] for _ in page_texts]

        # ── Passe 1 : identifier les pages d'en-tête d'item ─────────────────────
        header_pages: list[tuple[int, int, RangType, str]] = []

        for page_num, text in enumerate(page_texts):
            match = _ITEM_HEADER_PATTERN.search(text)
            if match is None:
                continue

            item_number = int(match.group(1))
            tables: PageTables = (
                page_tables[page_num] if page_num < len(page_tables) else []
            )

            # Rang depuis les tables pdfplumber (méthode principale)
            rang = self._rang_from_tables(tables)

            # Fallback : rang depuis le texte OCR brut (pytesseract)
            if rang is None:
                rang = self._rang_from_text(text)

            # Si aucun signal de rang, n'accepter comme header que si "Item N"
            # est en tout début de page (heading, pas une référence inline).
            if rang is None:
                if match.start() > _MAX_HEADER_POSITION:
                    logger.debug(
                        "Skipping 'Item %d' at position %d on page %d (likely cross-reference)",
                        item_number,
                        match.start(),
                        page_num,
                    )
                    continue
                logger.warning(
                    "Rang not found for item %d on page %d — defaulting to 'A'",
                    item_number,
                    page_num,
                )
                rang = "A"

            chapter_title = self._extract_chapter(text)
            header_pages.append((page_num, item_number, rang, chapter_title))

        if not header_pages:
            logger.warning("No item header pages detected in %d pages", len(page_texts))
            return []

        logger.info("Found %d item header pages", len(header_pages))

        # ── Passe 2 : délimiter le contenu de chaque item ───────────────────────
        items: list[DetectedItem] = []
        total_pages = len(page_texts)

        for i, (start_page, item_number, rang, chapter_title) in enumerate(header_pages):
            end_page = (
                header_pages[i + 1][0] - 1
                if i + 1 < len(header_pages)
                else total_pages - 1
            )

            item_page_texts = page_texts[start_page : end_page + 1]
            item_page_scores = page_scores[start_page : end_page + 1]

            avg_score = (
                sum(item_page_scores) / len(item_page_scores)
                if item_page_scores
                else 0.0
            )

            items.append(
                DetectedItem(
                    item_number=item_number,
                    rang=rang,
                    chapter_title=chapter_title,
                    ocr_text="\n".join(item_page_texts),
                    start_page=start_page,
                    end_page=end_page,
                    ocr_confidence_score=round(avg_score, 4),
                )
            )

        logger.info("Detected %d items from %d pages", len(items), total_pages)
        return items

    @staticmethod
    def _rang_from_tables(tables: PageTables) -> RangType | None:
        """Extraire le rang dominant depuis les tableaux pdfplumber.

        Cherche une table ayant une colonne dont l'en-tête contient "Rang",
        collecte toutes les valeurs A/B/C dans cette colonne, et retourne
        le rang de plus haute priorité (A > B > C).
        """
        rangs_found: set[str] = set()

        for table in tables:
            if not table:
                continue

            # Localiser la colonne "Rang" dans la première ligne (en-tête)
            rang_col: int | None = None
            for col_idx, cell in enumerate(table[0]):
                if cell and "rang" in cell.strip().lower():
                    rang_col = col_idx
                    break
            if rang_col is None:
                continue

            # Collecter les valeurs de la colonne (en sautant l'en-tête)
            for row in table[1:]:
                if rang_col < len(row):
                    cell_val = (row[rang_col] or "").strip().upper()
                    if cell_val in _RANG_VALID:
                        rangs_found.add(cell_val)

        if not rangs_found:
            return None

        # Retourner le rang de priorité la plus haute (A > B > C)
        return min(rangs_found, key=lambda r: _RANG_PRIORITY.get(r, 99))  # type: ignore[return-value]

    @staticmethod
    def _rang_from_text(text: str) -> RangType | None:
        """Fallback pytesseract : détecter le rang dans le texte brut du tableau OCR.

        Cherche le bloc "Rang Rubrique …" puis parse les lignes commençant par A, B ou C.
        """
        lines = text.splitlines()
        in_rang_table = False
        rangs_found: set[str] = set()

        for line in lines:
            stripped = line.strip()

            # Détecter l'en-tête du tableau rang (ex: "Rang  Rubrique  Intitulé")
            if re.search(r"\brang\b", stripped, re.IGNORECASE) and re.search(
                r"rubrique|intitul", stripped, re.IGNORECASE
            ):
                in_rang_table = True
                continue

            if not in_rang_table:
                continue

            # Fin du tableau : section de contenu textuel (I. INTRODUCTION, 1. ...)
            if re.match(r"^[IVX]+\.", stripped) or re.match(r"^\d+\.", stripped):
                break

            # Ligne de rang : commence par A, B ou C suivi d'un espace
            rang_match = re.match(r"^([ABC])\s", stripped)
            if rang_match:
                rangs_found.add(rang_match.group(1).upper())

        if not rangs_found:
            return None

        return min(rangs_found, key=lambda r: _RANG_PRIORITY.get(r, 99))  # type: ignore[return-value]

    @staticmethod
    def _extract_chapter(text: str) -> str:
        match = _CHAPTER_PATTERN.search(text)
        if match:
            return match.group(1).strip()[:200]
        return ""
