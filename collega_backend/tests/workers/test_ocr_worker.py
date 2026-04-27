"""Tests du worker OCR — reprise depuis page_texts_json, statuts, items créés.

Toutes les dépendances externes (DB, OCR libs) sont mockées.
Les modèles SQLAlchemy sont simulés avec SimpleNamespace pour éviter l'instrumentalisation.
"""
from __future__ import annotations

import json
import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.college import CollegeStatus
from app.services.ocr.item_detector import DetectedItem
from app.services.ocr.ocr_processor import OcrPageResult
from app.workers.ocr_worker import _run_ocr


def make_college(progress: int = 0, total_pages: int | None = None):
    """SimpleNamespace simule un College SQLAlchemy sans instrumentalisation."""
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        status=CollegeStatus.pending,
        ocr_page_progress=progress,
        total_pages=total_pages,
    )


def make_job(page_texts_json: str | None = None):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        status="pending",
        arq_job_id=None,
        error_message=None,
        page_texts_json=page_texts_json,
    )


def make_page_result(page_num: int, score: float = 0.85) -> OcrPageResult:
    return OcrPageResult(
        page_num=page_num,
        text=f"Item {page_num + 1} - Rang A\nContenu de la page {page_num}.",
        confidence_score=score,
        method="pdfplumber",
    )


def make_detected_item(item_number: int, score: float = 0.85) -> DetectedItem:
    return DetectedItem(
        item_number=item_number,
        rang="A",
        chapter_title="Cardiologie",
        ocr_text=f"Contenu item {item_number}",
        start_page=0,
        end_page=0,
        ocr_confidence_score=score,
    )


class TestRunOcr:
    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_processes_all_pages(self, mock_processor, mock_detector):
        """AC#1 — toutes les pages sont traitées et les items créés."""
        mock_processor.count_pages.return_value = 3
        mock_processor.process_page.side_effect = [
            make_page_result(0),
            make_page_result(1),
            make_page_result(2),
        ]
        mock_detector.detect_items.return_value = [
            make_detected_item(1),
            make_detected_item(2),
        ]

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        college = make_college(progress=0)
        job = make_job()

        result = await _run_ocr(db, college, job, "/fake/path.pdf")

        assert result["item_count"] == 2
        assert result["total_pages"] == 3
        assert mock_processor.process_page.call_count == 3

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_resumes_from_stored_page_texts(self, mock_processor, mock_detector):
        """AC#3 — reprise depuis page_texts_json (NFR11), ne retraite pas les pages déjà stockées."""
        mock_processor.count_pages.return_value = 10
        # Reprise depuis la page 5 — seulement 5 pages restantes (5 à 9)
        mock_processor.process_page.side_effect = [make_page_result(i) for i in range(5, 10)]
        mock_detector.detect_items.return_value = [make_detected_item(1)]

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        college = make_college(progress=5)
        # Simuler 5 pages déjà stockées dans page_texts_json
        previous_data = {
            "texts": [f"Item {i} - Rang A\nContenu page {i}" for i in range(5)],
            "scores": [0.85] * 5,
        }
        job = make_job(page_texts_json=json.dumps(previous_data))

        await _run_ocr(db, college, job, "/fake/path.pdf")

        # Seulement 5 appels (pages 5 à 9)
        assert mock_processor.process_page.call_count == 5
        # Vérifie que la première page traitée est la page 5
        first_call_args = mock_processor.process_page.call_args_list[0]
        assert first_call_args[0][1] == 5  # page_num = 5

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_progress_persisted_after_each_page(self, mock_processor, mock_detector):
        """AC#3 — ocr_page_progress est persisté après chaque page (reprise fine)."""
        mock_processor.count_pages.return_value = 3
        mock_processor.process_page.side_effect = [make_page_result(i) for i in range(3)]
        mock_detector.detect_items.return_value = []

        commit_count = 0
        progress_snapshots: list[int] = []
        college = make_college(progress=0)
        job = make_job()

        async def capture_commit():
            nonlocal commit_count
            commit_count += 1
            progress_snapshots.append(college.ocr_page_progress)

        db = AsyncMock()
        db.commit = capture_commit
        db.add = MagicMock()

        await _run_ocr(db, college, job, "/fake/path.pdf")

        # Au moins 3 commits de progression (un par page)
        page_progresses = [p for p in progress_snapshots if 1 <= p <= 3]
        assert len(page_progresses) >= 3, f"Expected at least 3 page-progress commits, got {progress_snapshots}"

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_status_transitions_to_ocr_complete(self, mock_processor, mock_detector):
        """AC#1 — le statut final est 'ocr_complete'."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0)
        mock_detector.detect_items.return_value = [make_detected_item(1)]

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        college = make_college()
        job = make_job()

        await _run_ocr(db, college, job, "/fake/path.pdf")

        assert college.status == CollegeStatus.ocr_complete
        assert job.status == "ocr_complete"

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_low_confidence_items_still_created(self, mock_processor, mock_detector):
        """AC#2 — les items avec score < 0.7 sont créés quand même (low_confidence=True)."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0, score=0.5)
        mock_detector.detect_items.return_value = [
            make_detected_item(1, score=0.5)
        ]

        added_items = []
        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock(side_effect=lambda item: added_items.append(item))

        college = make_college()
        job = make_job()

        result = await _run_ocr(db, college, job, "/fake/path.pdf")

        # L'item est bien créé malgré le faible score
        assert result["item_count"] == 1
        from app.models.item import Item
        created_items = [i for i in added_items if isinstance(i, Item)]
        assert len(created_items) == 1
        assert created_items[0].low_confidence is True
        assert created_items[0].ocr_confidence_score == pytest.approx(0.5, abs=0.001)

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_empty_pdf_sets_failed_status(self, mock_processor, mock_detector):
        """PDF vide (0 pages) → statut failed, pas ocr_complete silencieux."""
        mock_processor.count_pages.return_value = 0

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        college = make_college()
        job = make_job()

        result = await _run_ocr(db, college, job, "/fake/path.pdf")

        assert result.get("error") == "empty_pdf"
        assert job.status == "failed"
        assert college.status == CollegeStatus.failed
        mock_processor.process_page.assert_not_called()

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_retry_deletes_existing_items_before_reinsert(self, mock_processor, mock_detector):
        """Worker retry — les items existants sont supprimés avant réinsertion (pas de doublons)."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0)
        mock_detector.detect_items.return_value = [make_detected_item(1)]

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        college = make_college()
        job = make_job()

        await _run_ocr(db, college, job, "/fake/path.pdf")

        # db.execute doit avoir été appelé (pour le DELETE Item)
        db.execute.assert_called()

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_page_texts_cleared_after_completion(self, mock_processor, mock_detector):
        """page_texts_json est remis à None après completion — données intermédiaires nettoyées."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0)
        mock_detector.detect_items.return_value = []

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        college = make_college()
        job = make_job()

        await _run_ocr(db, college, job, "/fake/path.pdf")

        assert job.page_texts_json is None
