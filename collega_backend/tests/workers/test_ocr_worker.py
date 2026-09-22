"""Tests du worker OCR — reprise depuis page_texts_json, statuts, items créés.

Toutes les dépendances externes (DB, OCR libs) sont mockées.
Les modèles SQLAlchemy sont simulés avec SimpleNamespace pour éviter l'instrumentalisation.
"""
from __future__ import annotations

import json
import types
import uuid
from unittest.mock import AsyncMock, MagicMock, call, patch

import pytest

from app.models.college import CollegeStatus
from app.services.ocr.item_detector import DetectedItem
from app.services.ocr.ocr_processor import OcrPageResult
from app.workers.ocr_worker import _run_ocr


@pytest.fixture(autouse=True)
def _stub_referential():
    """Le référentiel de titres (story 8.0) fait du SQL réel : neutralisé ici, testé à part."""
    with patch("app.workers.ocr_worker.record_title", new_callable=AsyncMock) as record, patch(
        "app.workers.ocr_worker.lookup_title", new_callable=AsyncMock, return_value=None
    ) as lookup:
        yield record, lookup


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


def make_page_result(page_num: int, score: float = 0.85, tables=None) -> OcrPageResult:
    return OcrPageResult(
        page_num=page_num,
        text=f"Item {page_num + 1}\nTitre item {page_num + 1}.\nRang Rubrique Intitulé\nA Def Connaître...",
        confidence_score=score,
        method="pdfplumber",
        tables=tables or [],
    )


def make_detected_item(item_number: int, score: float = 0.85, rang: str = "A") -> DetectedItem:
    return DetectedItem(
        item_number=item_number,
        rang=rang,
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

        result = await _run_ocr(db, make_college(), make_job(), "/fake/path.pdf")

        assert result["item_count"] == 2
        assert result["total_pages"] == 3
        assert mock_processor.process_page.call_count == 3

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_page_tables_passed_to_detector(self, mock_processor, mock_detector):
        """Les tables extraites par OcrProcessor sont transmises à detect_items."""
        fake_table = [["Rang", "Rubrique"], ["A", "Def"]]
        mock_processor.count_pages.return_value = 2
        mock_processor.process_page.side_effect = [
            make_page_result(0, tables=[fake_table]),
            make_page_result(1, tables=[]),
        ]
        mock_detector.detect_items.return_value = [make_detected_item(1)]

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        await _run_ocr(db, make_college(), make_job(), "/fake/path.pdf")

        # detect_items doit être appelé avec page_tables contenant les tables des 2 pages
        call_kwargs = mock_detector.detect_items.call_args
        page_tables_arg = call_kwargs[0][2]  # 3ème arg positionnel
        assert page_tables_arg[0] == [fake_table]
        assert page_tables_arg[1] == []

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_resumes_from_stored_page_texts(self, mock_processor, mock_detector):
        """AC#3 — reprise depuis page_texts_json, ne retraite pas les pages déjà stockées."""
        mock_processor.count_pages.return_value = 10
        mock_processor.process_page.side_effect = [make_page_result(i) for i in range(5, 10)]
        mock_detector.detect_items.return_value = [make_detected_item(1)]

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        previous_data = {
            "texts": [f"Item {i}\nContenu page {i}" for i in range(5)],
            "scores": [0.85] * 5,
            "tables": [[] for _ in range(5)],
        }
        job = make_job(page_texts_json=json.dumps(previous_data))

        await _run_ocr(db, make_college(progress=5), job, "/fake/path.pdf")

        # Seulement 5 appels (pages 5 à 9), pas de retraitement des pages 0–4
        assert mock_processor.process_page.call_count == 5
        assert mock_processor.process_page.call_args_list[0][0][1] == 5

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_resumes_without_tables_in_stored_json(self, mock_processor, mock_detector):
        """Reprise depuis un ancien job_texts_json sans clé 'tables' — compatibilité."""
        mock_processor.count_pages.return_value = 3
        mock_processor.process_page.side_effect = [make_page_result(i) for i in range(1, 3)]
        mock_detector.detect_items.return_value = []

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        # Ancien format sans "tables"
        previous_data = {"texts": ["contenu page 0"], "scores": [0.9]}
        job = make_job(page_texts_json=json.dumps(previous_data))

        await _run_ocr(db, make_college(progress=1), job, "/fake/path.pdf")

        # Doit traiter seulement les pages 1 et 2
        assert mock_processor.process_page.call_count == 2

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_progress_persisted_after_each_page(self, mock_processor, mock_detector):
        """AC#3 — ocr_page_progress est persisté après chaque page."""
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

        page_progresses = [p for p in progress_snapshots if 1 <= p <= 3]
        assert len(page_progresses) >= 3, (
            f"Expected ≥3 page-progress commits, got {progress_snapshots}"
        )

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
        """AC#2 — les items avec score < 0.7 sont créés avec low_confidence=True."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0, score=0.5)
        mock_detector.detect_items.return_value = [make_detected_item(1, score=0.5)]

        added_items = []
        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock(side_effect=lambda item: added_items.append(item))

        result = await _run_ocr(db, make_college(), make_job(), "/fake/path.pdf")

        assert result["item_count"] == 1
        from app.models.item import Item
        created = [i for i in added_items if isinstance(i, Item)]
        assert len(created) == 1
        assert created[0].low_confidence is True
        assert created[0].ocr_confidence_score == pytest.approx(0.5, abs=0.001)

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_stops_when_job_cancelled_externally(self, mock_processor, mock_detector):
        """review 7.7 D1 — si l'admin force l'arrêt (status=failed) pendant l'OCR,
        le worker s'arrête sans traiter de page ni écraser le statut."""
        mock_processor.count_pages.return_value = 3
        mock_processor.process_page.side_effect = [make_page_result(i) for i in range(3)]
        mock_detector.detect_items.return_value = []

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()
        # La garde anti-race lit le statut → "failed" dès la 1re itération
        db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value="failed"))
        )

        result = await _run_ocr(db, make_college(), make_job(), "/fake/path.pdf")

        assert result.get("error") == "cancelled"
        # Aucune page traitée : on a bailé avant le premier process_page
        mock_processor.process_page.assert_not_called()

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_empty_pdf_sets_failed_status(self, mock_processor, mock_detector):
        """PDF vide (0 pages) → statut failed."""
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
        """Worker retry — les items existants sont supprimés avant réinsertion."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0)
        mock_detector.detect_items.return_value = [make_detected_item(1)]

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        await _run_ocr(db, make_college(), make_job(), "/fake/path.pdf")

        db.execute.assert_called()

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_page_texts_cleared_after_completion(self, mock_processor, mock_detector):
        """page_texts_json est remis à None après completion."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0)
        mock_detector.detect_items.return_value = []

        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock()

        job = make_job()
        await _run_ocr(db, make_college(), job, "/fake/path.pdf")

        assert job.page_texts_json is None

    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_dedup_keeps_item_with_most_content(self, mock_processor, mock_detector):
        """Deux occurrences du même item_number → garde celle avec le plus de texte."""
        mock_processor.count_pages.return_value = 1
        mock_processor.process_page.return_value = make_page_result(0)
        mock_detector.detect_items.return_value = [
            make_detected_item(42, rang="A"),
            DetectedItem(
                item_number=42,
                rang="B",
                chapter_title="",
                ocr_text="A" * 500,  # plus de contenu
                start_page=1,
                end_page=2,
                ocr_confidence_score=0.9,
            ),
        ]

        added_items = []
        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock(side_effect=lambda item: added_items.append(item))

        result = await _run_ocr(db, make_college(), make_job(), "/fake/path.pdf")

        # Un seul item après dédup
        assert result["item_count"] == 1
        from app.models.item import Item
        created = [i for i in added_items if isinstance(i, Item)]
        assert len(created) == 1
        # La seconde occurrence a plus de contenu → gardée (rang B)
        assert created[0].rang == "B"


class TestTitleCascade:
    """Story 8.0 — en-tête valide → référentiel → NULL + warning."""

    @staticmethod
    def _db(added):
        db = AsyncMock()
        db.commit = AsyncMock()
        db.add = MagicMock(side_effect=lambda obj: added.append(obj))
        return db

    @staticmethod
    def _detected(number: int, title: str) -> DetectedItem:
        return DetectedItem(
            item_number=number, rang="A", chapter_title=title, ocr_text="x",
            start_page=0, end_page=0, ocr_confidence_score=0.9,
        )

    @staticmethod
    def _created(added):
        from app.models.item import Item
        return {i.item_number: i for i in added if isinstance(i, Item)}

    @patch("app.workers.ocr_worker.lookup_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker.record_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_valid_title_kept_and_recorded(self, proc, det, record, lookup):
        proc.count_pages.return_value = 1
        proc.process_page.return_value = make_page_result(0)
        det.detect_items.return_value = [self._detected(310, "Tumeurs du testicule")]
        record.return_value = True
        added = []

        await _run_ocr(self._db(added), make_college(), make_job(), "/fake.pdf")

        assert self._created(added)[310].chapter_title == "Tumeurs du testicule"
        assert record.await_args.args[1:] == (310, "Tumeurs du testicule")
        lookup.assert_not_awaited()

    @patch("app.workers.ocr_worker.lookup_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker.record_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_missing_title_taken_from_referential(self, proc, det, record, lookup):
        """T5 non-régression : jamais de titre vide quand le référentiel en a un."""
        proc.count_pages.return_value = 1
        proc.process_page.return_value = make_page_result(0)
        det.detect_items.return_value = [self._detected(309, "")]
        lookup.return_value = "Tumeurs du poumon, primitives et secondaires"
        added = []

        await _run_ocr(self._db(added), make_college(), make_job(), "/fake.pdf")

        assert self._created(added)[309].chapter_title == (
            "Tumeurs du poumon, primitives et secondaires"
        )
        record.assert_not_awaited()

    @patch("app.workers.ocr_worker.lookup_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker.record_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_no_title_anywhere_is_null_with_warning(self, proc, det, record, lookup, caplog):
        proc.count_pages.return_value = 1
        proc.process_page.return_value = make_page_result(0)
        det.detect_items.return_value = [self._detected(313, "")]
        lookup.return_value = None
        added = []
        college = make_college()

        with caplog.at_level("WARNING", logger="app.workers.ocr_worker"):
            await _run_ocr(self._db(added), college, make_job(), "/fake.pdf")

        assert self._created(added)[313].chapter_title is None
        assert any(
            "313" in r.getMessage() and str(college.id) in r.getMessage()
            for r in caplog.records
        )

    @patch("app.workers.ocr_worker.lookup_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker.record_title", new_callable=AsyncMock)
    @patch("app.workers.ocr_worker._item_detector")
    @patch("app.workers.ocr_worker._ocr_processor")
    async def test_referential_failure_does_not_break_import(self, proc, det, record, lookup):
        proc.count_pages.return_value = 1
        proc.process_page.return_value = make_page_result(0)
        det.detect_items.return_value = [self._detected(310, "Tumeurs du testicule")]
        record.side_effect = RuntimeError("db down")
        added = []

        result = await _run_ocr(self._db(added), make_college(), make_job(), "/fake.pdf")

        assert result["item_count"] == 1
        assert self._created(added)[310].chapter_title == "Tumeurs du testicule"
