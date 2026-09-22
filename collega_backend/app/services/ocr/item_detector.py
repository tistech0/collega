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

from app.services.ocr.item_titles import clean_title, is_valid_title

logger = logging.getLogger(__name__)

# Pattern item : "Item 75", "Item n°110", "ITEM 330"
# Ancré en début de ligne (re.MULTILINE) pour ne pas matcher "voir item 42" mid-sentence.
# Tolère la ponctuation OCR en tête (". Item 313", CNEC) mais pas les puces (« • Item 230 »
# est une référence dans le corps). Pas « tem 313 » : ces en-têtes tronqués le sont souvent
# aussi à droite (« tem 30 » pour 306) et créeraient de faux items.
_ITEM_HEADER_PATTERN = re.compile(
    r"^[.,'’ \t]{0,3}item\s*n?°?\s*(\d{1,3})\b", re.IGNORECASE | re.MULTILINE
)
# Compte des numéros d'un sommaire : motif strict (« Item N » en tout début de ligne), pour
# qu'une liste « - Item 12 / - Item 45 » d'items liés ne fasse pas passer une page pour un sommaire.
_TOC_ITEM_PATTERN = re.compile(r"^item\s*n?°?\s*(\d{1,3})\b", re.IGNORECASE | re.MULTILINE)
# Préfixe « Chapitre 18 : » d'une entrée de sommaire (y compris OCR abîmé « C' a ire 13 : »)
_TOC_CHAPTER_PREFIX = re.compile(r"^[^:\d]{1,15}?\d+\s*:\s*")
_TOC_LEADERS = re.compile(r"[.·…\s]{3,}[\s\-\d]*$")
# « OBJECTIFS: N° 304. Tumeurs du foie… » (variantes OCR : « OBJECTIFS : », « N"o300. »)
_OBJECTIFS_PATTERN = re.compile(
    r"OBJECTIFS?\s*:?\s*N\s*[°º\"'o]{0,3}\s*(\d{1,3})\s*[.\-–:][ \t]*(.*)"
)
# Au-delà de ce nombre de numéros d'item distincts en début de ligne, la page est un sommaire.
_TOC_MIN_ITEM_NUMBERS = 3
_MAX_TITLE_LINES = 3
_TABLE_HEADER_LINE = re.compile(r"\s*(?:rang|rubrique)\b", re.IGNORECASE)

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


@dataclass
class _Header:
    page: int
    item_number: int
    rangs: list[RangType]
    # Vrai si « Item N » se répète sur les pages suivantes (en-tête courant, format CNEC) :
    # la ligne sous l'en-tête est alors du corps de texte, pas un titre.
    running: bool = False
    last_page: int = -1


def _is_table_of_contents(text: str) -> bool:
    numbers = {m.group(1) for m in _TOC_ITEM_PATTERN.finditer(text)}
    return len(numbers) >= _TOC_MIN_ITEM_NUMBERS


def _join_title_lines(first: str, following: list[str]) -> str:
    """Titre = première ligne + lignes de continuation (qui commencent par une minuscule)."""
    if _TABLE_HEADER_LINE.match(first):
        return ""
    parts = [first]
    for line in following:
        stripped = line.strip()
        if len(parts) >= _MAX_TITLE_LINES or not stripped or not stripped[0].islower():
            break
        parts.append(stripped)
    return clean_title(" ".join(parts))


def _titles_from_objectifs(page_texts: list[str]) -> dict[int, str]:
    titles: dict[int, str] = {}
    for text in page_texts:
        for match in _OBJECTIFS_PATTERN.finditer(text):
            number = int(match.group(1))
            if number in titles:
                continue
            first = match.group(2).strip()
            following = text[match.end() :].splitlines()[1:]
            if not first:
                # « OBJECTIFS: N° 304. » puis le titre seul sur la ligne suivante
                following = [line for line in following if line.strip()]
                if not following:
                    continue
                first, following = following[0].strip(), following[1:]
            title = _join_title_lines(first, following)
            if is_valid_title(title):
                titles[number] = title
    return titles


def _title_from_header(text: str) -> str:
    """Titre sur la ligne « Item N – Titre » ou sur la/les ligne(s) suivante(s)."""
    match = _ITEM_HEADER_PATTERN.search(text)
    if match is None:
        return ""
    lines = text[match.end() :].splitlines()
    rest = clean_title(lines[0]) if lines else ""
    following = lines[1:]
    if not rest:
        while following and not following[0].strip():
            following = following[1:]
        if not following:
            return ""
        rest, following = following[0].strip(), following[1:]
    title = _join_title_lines(rest, following)
    return title if is_valid_title(title) else ""


def _titles_from_toc(page_texts: list[str]) -> dict[int, str]:
    """Sommaire « Chapitre 18 : Tumeurs du pancréas ..... 307 / Item 308 » → {308: titre}."""
    titles: dict[int, str] = {}
    for text in page_texts:
        if not _is_table_of_contents(text):
            continue
        buffer: list[str] = []
        for line in text.splitlines():
            match = _ITEM_HEADER_PATTERN.match(line)
            if match is None:
                # Lignes de titre : ont des minuscules et au moins 3 lettres (écarte
                # « SOMMAIRE », « ► », les numéros de page seuls, les miettes OCR).
                if sum(c.isalpha() for c in line) >= 3 and any(c.islower() for c in line):
                    buffer.append(_TOC_LEADERS.sub("", line.strip()))
                continue
            number = int(match.group(1))
            entry = " ".join(buffer)
            buffer = []
            # Seules les entrées « Chapitre N : titre … Item N » sont sûres : un sommaire
            # qui met le titre sous le numéro décalerait toutes les attributions d'un rang.
            if not _TOC_CHAPTER_PREFIX.match(entry):
                continue
            title = clean_title(_TOC_CHAPTER_PREFIX.sub("", entry))
            if number not in titles and is_valid_title(title):
                titles[number] = title
    return titles


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
        # Un en-tête = (page de départ, numéro, signaux de rang collectés sur le span).
        # Les pages consécutives portant le même « Item N » (en-tête courant, CNEC)
        # forment un seul item : on les fusionne au lieu d'en faire N items d'une page.
        headers: list[_Header] = []

        for page_num, text in enumerate(page_texts):
            match = _ITEM_HEADER_PATTERN.search(text)
            if match is None:
                continue

            if _is_table_of_contents(text):
                logger.debug("Skipping page %d: table of contents", page_num)
                continue

            item_number = int(match.group(1))
            tables: PageTables = (
                page_tables[page_num] if page_num < len(page_tables) else []
            )

            # Rang depuis les tables pdfplumber (méthode principale),
            # puis fallback texte OCR brut (pytesseract)
            rang = self._rang_from_tables(tables) or self._rang_from_text(text)

            if headers and headers[-1].item_number == item_number:
                # Courant seulement si répété sur la page suivante (« Item 359 bis »
                # 14 pages plus loin est une sous-section, pas un en-tête courant).
                if page_num == headers[-1].last_page + 1:
                    headers[-1].running = True
                headers[-1].last_page = page_num
                if rang is not None:
                    headers[-1].rangs.append(rang)
                continue

            # Si aucun signal de rang, n'accepter comme header que si "Item N"
            # est en tout début de page (heading, pas une référence inline).
            if rang is None and match.start() > _MAX_HEADER_POSITION:
                logger.debug(
                    "Skipping 'Item %d' at position %d on page %d (likely cross-reference)",
                    item_number,
                    match.start(),
                    page_num,
                )
                continue

            headers.append(
                _Header(
                    page=page_num,
                    item_number=item_number,
                    rangs=[rang] if rang is not None else [],
                    last_page=page_num,
                )
            )

        if not headers:
            logger.warning("No item header pages detected in %d pages", len(page_texts))
            return []

        logger.info("Found %d item header pages", len(headers))

        # Sources de titre, par priorité : « OBJECTIFS: N° N. Titre » (CNEC, le plus
        # complet) → sommaire → ligne(s) d'en-tête de la première page de l'item.
        objectifs_titles = _titles_from_objectifs(page_texts)
        toc_titles = _titles_from_toc(page_texts)

        # ── Passe 2 : délimiter le contenu de chaque item ───────────────────────
        items: list[DetectedItem] = []
        total_pages = len(page_texts)

        for i, header in enumerate(headers):
            start_page = header.page
            item_number = header.item_number
            end_page = (
                headers[i + 1].page - 1 if i + 1 < len(headers) else total_pages - 1
            )

            if header.rangs:
                rang: RangType = min(header.rangs, key=lambda r: _RANG_PRIORITY.get(r, 99))
            else:
                logger.warning(
                    "Rang not found for item %d on page %d — defaulting to 'A'",
                    item_number,
                    start_page,
                )
                rang = "A"

            item_page_texts = page_texts[start_page : end_page + 1]
            chapter_title = (
                objectifs_titles.get(item_number)
                or toc_titles.get(item_number)
                or ("" if header.running else _title_from_header(item_page_texts[0]))
            )
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
