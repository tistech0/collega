"""Tests de la capture d'usage tokens dans le pipeline génération — Story 7.8 AC1.

Vérifie que `generate_for_college` cumule `input_tokens`/`output_tokens` sur le job
(génération réelle), met 0/0 en hash-sharing, et garde l'usage même si le parsing
JSON d'un item échoue (cards=[] mais tokens facturés).
"""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

from app.services.generation.card_generator import CardGenerator
from app.services.generation.claude_client import CardGenResult, FlashCardData


def make_job(status: str = "ocr_complete", user_id=None):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        college_id=uuid.uuid4(),
        status=status,
        user_id=user_id or uuid.uuid4(),
        pdf_hash=None,
        hash_shared=False,
        card_count=0,
        input_tokens=None,
        output_tokens=None,
        error_message=None,
    )


def make_item(item_number: int = 1, rang: str = "A", ocr_text: str = "Texte OCR item"):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        item_number=item_number,
        rang=rang,
        ocr_text=ocr_text,
        ocr_confidence_score=0.85,
        low_confidence=False,
    )


class TestTokenUsageCapture:
    async def test_accumulates_usage_across_items(self):
        """Génération réelle : l'usage de chaque item est cumulé sur le job."""
        college_id = uuid.uuid4()
        job = make_job()

        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()

        items = [make_item(1), make_item(2), make_item(3)]
        scalars_items = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))
        db.execute = AsyncMock(return_value=scalars_items)

        generator = CardGenerator()
        per_item = [
            CardGenResult(cards=[FlashCardData("classique", "Q1", "R1")], input_tokens=100, output_tokens=40),
            CardGenResult(cards=[FlashCardData("classique", "Q2", "R2")], input_tokens=150, output_tokens=60),
            CardGenResult(cards=[FlashCardData("definition", "T3", "D3")], input_tokens=200, output_tokens=80),
        ]

        with patch.object(generator._similarity, "compute_hash", return_value="fakehash"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=None)):
                with patch.object(
                    generator._claude, "generate_cards_for_item", new=AsyncMock(side_effect=per_item)
                ):
                    await generator.generate_for_college(db, college_id, job.id, "/fake/path.pdf")

        assert job.input_tokens == 450  # 100+150+200
        assert job.output_tokens == 180  # 40+60+80
        assert job.status == "generation_complete"

    async def test_usage_kept_when_parsing_fails(self):
        """Un item dont le parsing échoue (cards=[]) compte quand même ses tokens."""
        college_id = uuid.uuid4()
        job = make_job()

        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()

        items = [make_item(1), make_item(2)]
        scalars_items = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))
        db.execute = AsyncMock(return_value=scalars_items)

        generator = CardGenerator()
        per_item = [
            # item 1 : parsing échoué → 0 fiche mais tokens facturés
            CardGenResult(cards=[], input_tokens=90, output_tokens=10),
            CardGenResult(cards=[FlashCardData("classique", "Q2", "R2")], input_tokens=110, output_tokens=30),
        ]

        with patch.object(generator._similarity, "compute_hash", return_value="fakehash"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=None)):
                with patch.object(
                    generator._claude, "generate_cards_for_item", new=AsyncMock(side_effect=per_item)
                ):
                    result = await generator.generate_for_college(db, college_id, job.id, "/fake/path.pdf")

        assert result["card_count"] == 1  # seul l'item 2 a produit une fiche
        assert job.input_tokens == 200  # 90 + 110 — l'usage de l'item raté est compté
        assert job.output_tokens == 40  # 10 + 30

    async def test_hash_sharing_sets_zero_usage(self):
        """Hash-sharing : Claude jamais appelé → usage explicitement 0/0."""
        college_id = uuid.uuid4()
        job = make_job()
        similar_job = make_job(status="generation_complete")
        similar_job.college_id = uuid.uuid4()

        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()

        source_item = make_item(item_number=1)
        target_item = make_item(item_number=1)
        source_card = types.SimpleNamespace(
            id=uuid.uuid4(),
            item_id=source_item.id,
            college_id=similar_job.college_id,
            card_type="classique",
            rang="A",
            recto="Q?",
            verso="R",
            ocr_confidence_score=0.85,
            low_confidence=False,
        )

        db.execute = AsyncMock(side_effect=[
            MagicMock(),  # DELETE idempotency
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[source_card])))),
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[target_item])))),
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[source_item])))),
            MagicMock(scalar_one_or_none=MagicMock(return_value=None)),  # _is_reimport → premier import
            MagicMock(),  # UPDATE colleges SET status=generation_complete
        ])

        generator = CardGenerator()

        with patch.object(generator._similarity, "compute_hash", return_value="fakehash"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=similar_job)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock()) as mock_claude:
                    result = await generator.generate_for_college(db, college_id, job.id, "/fake/path.pdf")

        mock_claude.assert_not_called()
        assert result["hash_shared"] is True
        assert job.input_tokens == 0
        assert job.output_tokens == 0
