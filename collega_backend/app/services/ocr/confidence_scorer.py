"""Calcul et classification du score de confiance OCR."""

from __future__ import annotations

from app.services.ocr.ocr_processor import OcrPageResult

LOW_CONFIDENCE_THRESHOLD = 0.7


class ConfidenceScorer:
    """Classifie les scores OCR et détermine le flag low_confidence."""

    def score(self, page_result: OcrPageResult) -> float:
        """Retourne le score de confiance 0.0–1.0 déjà calculé par OcrProcessor."""
        return round(page_result.confidence_score, 4)

    def is_low_confidence(self, score: float) -> bool:
        """Retourne True si le score est en dessous du seuil (< 0.7)."""
        return score < LOW_CONFIDENCE_THRESHOLD

    def aggregate_scores(self, scores: list[float]) -> float:
        """Calcule le score moyen sur une liste de pages."""
        if not scores:
            return 0.0
        return round(sum(scores) / len(scores), 4)
