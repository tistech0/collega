"""Tests du service CardGenerator — orchestration génération + hash-sharing."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

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


class TestCardGeneratorHashSharing:
    async def test_uses_existing_cards_when_hash_matches(self):
        """AC#2 — hash-sharing : copie les cartes sans appel Claude."""
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

        # Mock execute pour les différentes requêtes (DELETE idempotency + 3 SELECTs
        # de _copy_cards_for_hash_sharing + 1 SELECT de _is_reimport).
        delete_result = MagicMock()
        scalars_source_cards = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[source_card]))))
        scalars_target_items = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[target_item]))))
        scalars_source_items = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[source_item]))))
        # _is_reimport renvoie None → premier import → pas de compensation quota
        is_reimport_first_import = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        db.execute = AsyncMock(side_effect=[
            delete_result,
            scalars_source_cards,
            scalars_target_items,
            scalars_source_items,
            is_reimport_first_import,
            MagicMock(),  # UPDATE colleges SET status=generation_complete
        ])

        generator = CardGenerator()

        with patch.object(generator._similarity, "compute_hash", return_value="fakehash"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=similar_job)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock()) as mock_claude:
                    result = await generator.generate_for_college(db, college_id, job.id, "/fake/path.pdf")

        mock_claude.assert_not_called()
        assert result["hash_shared"] is True
        assert job.hash_shared is True
        assert job.status == "generation_complete"
        # Story 7.8 — hash-sharing = gratuit explicite 0/0 (Claude jamais appelé)
        assert job.input_tokens == 0
        assert job.output_tokens == 0

    async def test_calls_claude_when_no_hash_match(self):
        """AC#1 — appelle Claude pour chaque item quand pas de hash-sharing."""
        college_id = uuid.uuid4()
        job = make_job()

        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        added = []
        db.add = MagicMock(side_effect=lambda c: added.append(c))
        db.commit = AsyncMock()

        items = [make_item(1), make_item(2)]
        scalars_result = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))
        db.execute = AsyncMock(return_value=scalars_result)

        generator = CardGenerator()
        # Chaque item retourne 1 fiche + un usage de 100/50 → cumul 200/100 sur 2 items.
        gen_result = CardGenResult(
            cards=[FlashCardData(card_type="classique", recto="Q?", verso="R")],
            input_tokens=100,
            output_tokens=50,
        )

        with patch.object(generator._similarity, "compute_hash", return_value="fakehash"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=None)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock(return_value=gen_result)):
                    result = await generator.generate_for_college(db, college_id, job.id, "/fake/path.pdf")

        assert result["hash_shared"] is False
        assert result["card_count"] == 2
        assert job.status == "generation_complete"
        # Story 7.8 — usage cumulé sur le job (2 items × 100/50)
        assert job.input_tokens == 200
        assert job.output_tokens == 100
        # 2 FlashCard ajoutées (les events timeline Story 7.7 passent aussi par db.add,
        # on filtre donc par type pour cibler l'intention du test).
        from app.models.flash_card import FlashCard
        assert len([c for c in added if isinstance(c, FlashCard)]) == 2

    async def test_stops_generation_when_job_cancelled(self):
        """review 7.7 D1 — si l'admin force l'arrêt (status=failed) pendant la
        génération, on stoppe avant le prochain appel Claude et on n'écrase pas
        le statut."""
        college_id = uuid.uuid4()
        job = make_job()

        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()

        items = [make_item(1), make_item(2)]
        scalars_items = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))
        status_failed = MagicMock(scalar_one_or_none=MagicMock(return_value="failed"))
        # execute : [DELETE idempotency, SELECT items, garde anti-race → "failed"]
        db.execute = AsyncMock(side_effect=[MagicMock(), scalars_items, status_failed])

        generator = CardGenerator()

        with patch.object(generator._similarity, "compute_hash", return_value="fakehash"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=None)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock()) as mock_claude:
                    result = await generator.generate_for_college(db, college_id, job.id, "/fake/path.pdf")

        mock_claude.assert_not_called()
        assert result.get("cancelled") is True
        assert job.status != "generation_complete"

    async def test_hash_sharing_isolates_user_id(self):
        """AC#2 — NFR8 : chaque utilisateur a ses propres fiches (user_id du job cible)."""
        college_id = uuid.uuid4()
        target_user_id = uuid.uuid4()
        job = make_job(user_id=target_user_id)
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
            # _is_reimport → None : premier import → pas de compensation quota
            MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
            MagicMock(),  # UPDATE colleges SET status=generation_complete
        ])

        generator = CardGenerator()
        added_cards = []
        db.add = MagicMock(side_effect=lambda c: added_cards.append(c))

        with patch.object(generator._similarity, "compute_hash", return_value="fakehash"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=similar_job)):
                await generator.generate_for_college(db, college_id, job.id, "/fake/path.pdf")

        from app.models.flash_card import FlashCard
        flash_cards = [c for c in added_cards if isinstance(c, FlashCard)]
        assert len(flash_cards) == 1
        assert flash_cards[0].user_id == target_user_id


def _college_status_updates(db) -> list[str]:
    """Statuts écrits sur `colleges` via `UPDATE colleges SET status=...`."""
    from sqlalchemy.sql.dml import Update

    found = []
    for call in db.execute.await_args_list:
        stmt = call.args[0] if call.args else None
        if isinstance(stmt, Update) and stmt.table.name == "colleges":
            compiled = stmt.compile(compile_kwargs={"literal_binds": True})
            if "status" in compiled.params or "status" in str(compiled):
                found.append(str(compiled))
    return found


class TestCollegeStatusFinalisation:
    """Régression prod 2026-09-20 : le job passait à generation_complete mais
    jamais le College → /status figé sur ocr_complete, SSE sans événement
    final, /items en 409 (collège « vide » dans l'app et l'admin)."""

    async def test_claude_path_marks_college_generation_complete(self):
        college_id = uuid.uuid4()
        job = make_job()
        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()
        items = [make_item(1)]
        db.execute = AsyncMock(
            return_value=MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))
        )
        gen_result = CardGenResult(
            cards=[FlashCardData(card_type="classique", recto="Q?", verso="R")],
            input_tokens=1,
            output_tokens=1,
        )
        generator = CardGenerator()
        with patch.object(generator._similarity, "compute_hash", return_value="h"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=None)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock(return_value=gen_result)):
                    await generator.generate_for_college(db, college_id, job.id, "/fake.pdf")

        updates = _college_status_updates(db)
        assert updates, "aucun UPDATE colleges SET status exécuté"
        assert any("generation_complete" in u for u in updates), updates

    async def test_hash_sharing_path_marks_college_generation_complete(self):
        college_id = uuid.uuid4()
        job = make_job()
        similar_job = make_job(status="generation_complete")
        similar_job.college_id = uuid.uuid4()
        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()
        source_item, target_item = make_item(1), make_item(1)
        source_card = types.SimpleNamespace(
            id=uuid.uuid4(), item_id=source_item.id, college_id=similar_job.college_id,
            card_type="classique", rang="A", recto="Q?", verso="R",
            ocr_confidence_score=0.85, low_confidence=False,
        )
        scalars = lambda rows: MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=rows))))  # noqa: E731
        db.execute = AsyncMock(side_effect=[
            MagicMock(),                       # DELETE idempotency
            scalars([source_card]),
            scalars([target_item]),
            scalars([source_item]),
            MagicMock(scalar_one_or_none=MagicMock(return_value=None)),  # _is_reimport
            MagicMock(),                       # UPDATE colleges SET status
        ])
        generator = CardGenerator()
        with patch.object(generator._similarity, "compute_hash", return_value="h"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=similar_job)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock()):
                    await generator.generate_for_college(db, college_id, job.id, "/fake.pdf")

        updates = _college_status_updates(db)
        assert any("generation_complete" in u for u in updates), updates


class TestGenerationProgress:
    """Story 8.13 — compteur de fiches au fil de l'eau (écran d'import en cours)."""

    async def test_publie_l_avancement_par_item(self):
        college_id = uuid.uuid4()
        job = make_job()
        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()
        items = [make_item(1), make_item(2), make_item(3)]
        scalars_result = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=items))))
        db.execute = AsyncMock(return_value=scalars_result)

        calls = []

        async def reporter(cid, *, items_done, items_total, cards):
            calls.append((cid, items_done, items_total, cards))

        generator = CardGenerator(progress_reporter=reporter)
        two_cards = CardGenResult(
            cards=[FlashCardData(card_type="classique", recto="Q?", verso="R")] * 2,
            input_tokens=1,
            output_tokens=1,
        )
        with patch.object(generator._similarity, "compute_hash", return_value="h"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=None)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock(return_value=two_cards)):
                    await generator.generate_for_college(db, college_id, job.id, "/f.pdf")

        assert calls == [
            (college_id, 0, 3, 0),
            (college_id, 1, 3, 2),
            (college_id, 2, 3, 4),
            (college_id, 3, 3, 6),
        ]

    async def test_un_echec_de_publication_n_arrete_pas_la_generation(self):
        college_id = uuid.uuid4()
        job = make_job()
        db = AsyncMock()
        db.get = AsyncMock(return_value=job)
        db.add = MagicMock()
        db.commit = AsyncMock()
        scalars_result = MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[make_item(1)]))))
        db.execute = AsyncMock(return_value=scalars_result)

        async def failing(cid, *, items_done, items_total, cards):
            raise RuntimeError("db down")

        generator = CardGenerator(progress_reporter=failing)
        one = CardGenResult(cards=[FlashCardData(card_type="classique", recto="Q", verso="R")], input_tokens=1, output_tokens=1)
        with patch.object(generator._similarity, "compute_hash", return_value="h"):
            with patch.object(generator._similarity, "find_similar_job", new=AsyncMock(return_value=None)):
                with patch.object(generator._claude, "generate_cards_for_item", new=AsyncMock(return_value=one)):
                    result = await generator.generate_for_college(db, college_id, job.id, "/f.pdf")
        assert result["card_count"] == 1
        assert job.status == "generation_complete"
