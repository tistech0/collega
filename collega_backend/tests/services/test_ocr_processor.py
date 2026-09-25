"""Tests OcrProcessor — pdfplumber et pytesseract sont mockés."""

from unittest.mock import MagicMock, patch

import pytest

from app.services.ocr.ocr_processor import OcrPageResult, OcrProcessor


@pytest.fixture
def processor():
    return OcrProcessor()


def make_pdfplumber_mock(page_text: str, words: list | None = None):
    """Crée un mock pdfplumber.open() context manager."""
    mock_page = MagicMock()
    mock_page.extract_text.return_value = page_text
    mock_page.extract_words.return_value = words or [{"text": w} for w in page_text.split() if w]

    mock_pdf = MagicMock()
    mock_pdf.pages = [mock_page]
    mock_pdf.__enter__ = MagicMock(return_value=mock_pdf)
    mock_pdf.__exit__ = MagicMock(return_value=False)

    mock_open = MagicMock(return_value=mock_pdf)
    return mock_open


class TestProcessPage:
    @patch("app.services.ocr.ocr_processor.OcrProcessor._extract_with_pdfplumber")
    def test_returns_pdfplumber_result_when_text_sufficient(self, mock_extract, processor):
        expected = OcrPageResult(page_num=0, text="A" * 100, confidence_score=0.9, method="pdfplumber")
        mock_extract.return_value = expected

        result = processor.process_page("/fake/path.pdf", 0)
        assert result.method == "pdfplumber"
        assert result.confidence_score == 0.9

    @patch("app.services.ocr.ocr_processor.OcrProcessor._extract_with_pytesseract")
    @patch("app.services.ocr.ocr_processor.OcrProcessor._extract_with_pdfplumber")
    def test_fallback_to_pytesseract_when_text_too_short(self, mock_pdfplumber, mock_tesseract, processor):
        mock_pdfplumber.return_value = OcrPageResult(
            page_num=0, text="short", confidence_score=0.9, method="pdfplumber"
        )
        mock_tesseract.return_value = OcrPageResult(
            page_num=0, text="A" * 200, confidence_score=0.75, method="pytesseract"
        )

        result = processor.process_page("/fake/path.pdf", 0)
        assert result.method == "pytesseract"

    @patch("app.services.ocr.ocr_processor.OcrProcessor._extract_with_pytesseract")
    @patch("app.services.ocr.ocr_processor.OcrProcessor._extract_with_pdfplumber")
    def test_returns_empty_on_both_failures(self, mock_pdfplumber, mock_tesseract, processor):
        mock_pdfplumber.side_effect = Exception("PDF error")
        mock_tesseract.side_effect = Exception("Tesseract error")

        result = processor.process_page("/fake/path.pdf", 0)
        assert result.method == "empty"
        assert result.confidence_score == 0.0
        assert result.text == ""

    def test_pdfplumber_confidence_empty_text(self, processor):
        score = processor._pdfplumber_confidence("", [])
        assert score == 0.0

    def test_pdfplumber_confidence_full_coverage(self, processor):
        text = "hello world"
        words = [{"text": "hello"}, {"text": "world"}]
        score = processor._pdfplumber_confidence(text, words)
        assert score > 0.5

    def test_pdfplumber_confidence_no_words(self, processor):
        score = processor._pdfplumber_confidence("hello world", [])
        assert score == 0.0

    def test_count_pages_uses_pdfplumber(self, processor):
        """count_pages() délègue à pdfplumber.open() — pdfplumber simulé via sys.modules."""
        import sys

        mock_pdf = MagicMock()
        mock_pdf.pages = [MagicMock(), MagicMock(), MagicMock()]
        mock_pdf.__enter__ = MagicMock(return_value=mock_pdf)
        mock_pdf.__exit__ = MagicMock(return_value=False)

        mock_pdfplumber = MagicMock()
        mock_pdfplumber.open.return_value = mock_pdf

        with patch.dict(sys.modules, {"pdfplumber": mock_pdfplumber}):
            count = processor.count_pages("/fake/path.pdf")

        assert count == 3
