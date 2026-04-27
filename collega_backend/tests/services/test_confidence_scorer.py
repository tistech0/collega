"""Tests du ConfidenceScorer — logique pure Python, aucune dépendance externe."""
import pytest

from app.services.ocr.confidence_scorer import LOW_CONFIDENCE_THRESHOLD, ConfidenceScorer
from app.services.ocr.ocr_processor import OcrPageResult


@pytest.fixture
def scorer():
    return ConfidenceScorer()


def make_page_result(score: float) -> OcrPageResult:
    return OcrPageResult(page_num=0, text="test", confidence_score=score, method="pdfplumber")


class TestIsLowConfidence:
    def test_score_below_threshold_is_low_confidence(self, scorer):
        assert scorer.is_low_confidence(0.5) is True

    def test_score_at_threshold_is_not_low_confidence(self, scorer):
        # 0.7 est le seuil — valeur >= 0.7 = NOT low_confidence
        assert scorer.is_low_confidence(LOW_CONFIDENCE_THRESHOLD) is False

    def test_score_above_threshold_is_not_low_confidence(self, scorer):
        assert scorer.is_low_confidence(0.85) is False

    def test_zero_score_is_low_confidence(self, scorer):
        assert scorer.is_low_confidence(0.0) is True

    def test_perfect_score_is_not_low_confidence(self, scorer):
        assert scorer.is_low_confidence(1.0) is False


class TestScore:
    def test_score_returns_page_result_confidence(self, scorer):
        page_result = make_page_result(0.82)
        assert scorer.score(page_result) == 0.82

    def test_score_rounds_to_4_decimals(self, scorer):
        page_result = make_page_result(0.123456789)
        result = scorer.score(page_result)
        assert len(str(result).split(".")[-1]) <= 4


class TestAggregateScores:
    def test_aggregate_empty_returns_zero(self, scorer):
        assert scorer.aggregate_scores([]) == 0.0

    def test_aggregate_single(self, scorer):
        assert scorer.aggregate_scores([0.8]) == 0.8

    def test_aggregate_multiple(self, scorer):
        result = scorer.aggregate_scores([0.6, 0.8, 1.0])
        assert abs(result - 0.8) < 0.0001

    def test_ac2_low_confidence_flag(self, scorer):
        """AC#2 — items avec score < 0.7 sont marqués low_confidence."""
        scores_below = [0.3, 0.5, 0.69]
        scores_above = [0.7, 0.8, 1.0]
        for s in scores_below:
            assert scorer.is_low_confidence(s) is True, f"score {s} should be low_confidence"
        for s in scores_above:
            assert scorer.is_low_confidence(s) is False, f"score {s} should NOT be low_confidence"
