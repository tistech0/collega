"""Export CSV de tester_feedbacks avant sa suppression (chantier 5 R2), Postgres réel."""

import asyncio
import csv
from datetime import date

import pytest
from sqlalchemy import text

from alembic import command
from scripts.export_tester_feedbacks import export_tester_feedbacks, main
from tests.factories import make_card, make_college, make_item, make_user
from tests.pg import TEST_PG_URL, alembic_config

pytestmark = pytest.mark.pg


async def test_exports_rows_joined_to_card(pg_engine, pg_factory, tmp_path):
    # Lignes créées au schéma courant (les modèles ORM le suivent), puis retour au
    # schéma d'avant la 019 : la table tester_feedbacks existe encore.
    async with pg_factory() as db:
        college = await make_college(db, await make_user(db))
        card = await make_card(db, await make_item(db, college, 7), recto="Recto ?", verso="Verso")
        await db.commit()
    await asyncio.to_thread(command.downgrade, alembic_config(), "018")
    async with pg_factory() as db:
        await db.execute(
            text(
                "INSERT INTO tester_feedbacks (flash_card_id, college_id, tester_id, is_pertinent)"
                " VALUES (:card, :college, 'testeuse', false)"
            ),
            {"card": card.id, "college": college.id},
        )
        await db.commit()

    path = await export_tester_feedbacks(TEST_PG_URL, tmp_path, today=date(2026, 9, 24))

    assert path == tmp_path / "tester_feedbacks_20260924.csv"
    with path.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 1
    row = rows[0]
    assert row["flash_card_id"] == str(card.id)
    assert row["college_id"] == str(college.id)
    assert row["tester_id"] == "testeuse"
    assert row["is_pertinent"] == "False"
    assert (row["recto"], row["verso"], row["rang"]) == ("Recto ?", "Verso", "A")
    assert row["created_at"]


async def test_missing_table_is_not_an_error(pg_engine, tmp_path, monkeypatch, capsys):
    # Schéma à jour : la table a déjà été supprimée.
    assert await export_tester_feedbacks(TEST_PG_URL, tmp_path) is None
    assert list(tmp_path.iterdir()) == []

    monkeypatch.setenv("DATABASE_URL", TEST_PG_URL)
    assert await asyncio.to_thread(main, ["--out", str(tmp_path)]) == 0
    assert "n'existe plus" in capsys.readouterr().out
