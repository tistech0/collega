"""Détection des items ECNi et de leurs rangs dans le texte OCR.

Pattern ECNi : les PDFs des collèges médicaux (CNCEM, COFER, etc.) structurent
leur contenu autour d'items numérotés (Item N) avec des rangs (Rang A/B/C).
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Literal

logger = logging.getLogger(__name__)

# Patterns pour PDFs ECNi/CNCI
_ITEM_PATTERN = re.compile(r"item\s*n?°?\s*(\d{1,3})", re.IGNORECASE)
_RANG_PATTERN = re.compile(r"rang\s+([ABC])", re.IGNORECASE)
_CHAPTER_PATTERN = re.compile(r"(?:chapitre|partie)\s+(.{3,80}?)(?:\n|$)", re.IGNORECASE)

RangType = Literal["A", "B", "C"]


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
    """Détecte les items et leurs rangs dans une liste de textes OCR par page."""

    def detect_items(
        self,
        page_texts: list[str],
        page_scores: list[float] | None = None,
    ) -> list[DetectedItem]:
        """Extrait les items depuis les textes paginés.

        Args:
            page_texts: texte extrait par page (index = page_num)
            page_scores: score de confiance par page (même longueur que page_texts)
        """
        if page_scores is None:
            page_scores = [0.9] * len(page_texts)

        items: list[DetectedItem] = []
        current_item: dict | None = None
        current_pages: list[int] = []
        current_text_lines: list[str] = []

        for page_num, (text, score) in enumerate(zip(page_texts, page_scores)):
            lines = text.splitlines()
            for line in lines:
                item_match = _ITEM_PATTERN.search(line)
                if item_match:
                    # Sauvegarder l'item précédent
                    if current_item is not None:
                        items.append(
                            self._build_item(
                                current_item,
                                current_text_lines,
                                current_pages,
                                page_scores,
                            )
                        )
                    rang = self._extract_rang(line) or self._extract_rang(text)
                    if rang is None:
                        logger.warning(
                            "Rang not found for item %s on page %d — defaulting to 'A'",
                            item_match.group(1),
                            page_num,
                        )
                        rang = "A"
                    current_item = {
                        "item_number": int(item_match.group(1)),
                        "rang": rang,
                        "chapter_title": self._extract_chapter(text),
                    }
                    current_pages = [page_num]
                    current_text_lines = [line]
                elif current_item is not None:
                    current_text_lines.append(line)
                    if page_num not in current_pages:
                        current_pages.append(page_num)

        # Dernier item
        if current_item is not None:
            items.append(
                self._build_item(
                    current_item,
                    current_text_lines,
                    current_pages,
                    page_scores,
                )
            )

        return items

    @staticmethod
    def _extract_rang(text: str) -> RangType | None:
        match = _RANG_PATTERN.search(text)
        if match:
            rang = match.group(1).upper()
            if rang in ("A", "B", "C"):
                return rang  # type: ignore[return-value]
        return None

    @staticmethod
    def _extract_chapter(text: str) -> str:
        match = _CHAPTER_PATTERN.search(text)
        if match:
            return match.group(1).strip()[:200]
        return ""

    @staticmethod
    def _build_item(
        info: dict,
        text_lines: list[str],
        pages: list[int],
        page_scores: list[float],
    ) -> DetectedItem:
        relevant_scores = [page_scores[p] for p in pages if p < len(page_scores)]
        avg_score = (
            sum(relevant_scores) / len(relevant_scores) if relevant_scores else 0.0
        )
        return DetectedItem(
            item_number=info["item_number"],
            rang=info["rang"],
            chapter_title=info["chapter_title"],
            ocr_text="\n".join(text_lines),
            start_page=pages[0] if pages else 0,
            end_page=pages[-1] if pages else 0,
            ocr_confidence_score=round(avg_score, 4),
        )
