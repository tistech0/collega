"""Story 8.0 — logique de données de la migration 015 (référentiel item_titles), sur SQLite."""
import importlib.util
import uuid
from pathlib import Path

import pytest
from sqlalchemy import create_engine, select

import app.models  # noqa: F401
from app.core.database import Base
from app.models.item import Item
from app.models.item_title import ItemTitle

_spec = importlib.util.spec_from_file_location(
    "migration_015",
    Path(__file__).resolve().parents[1] / "alembic/versions/015_add_item_titles.py",
)
migration = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(migration)


@pytest.fixture
def conn():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with engine.begin() as connection:
        yield connection
    engine.dispose()


def _insert_item(conn, number, title):
    item_id = uuid.uuid4()
    conn.execute(
        Item.__table__.insert().values(
            id=item_id, college_id=uuid.uuid4(), item_number=number, rang="A",
            chapter_title=title, ocr_confidence_score=0.9, low_confidence=False,
            created_at=migration._now(),
        )
    )
    return item_id


def _titles(conn):
    return {
        r.id: r.chapter_title
        for r in conn.execute(select(Item.__table__.c.id, Item.__table__.c.chapter_title))
    }


def test_garbage_titles_are_cleared(conn):
    garbage = _insert_item(conn, 295, "d'un malade atteint de cancer")
    author = _insert_item(conn, 304, "Pr Michel Ducreux1, Pr Serge Evrard2")
    migration.seed_and_backfill(conn)
    titles = _titles(conn)
    assert titles[garbage] is None
    assert titles[author] is None
    assert conn.execute(select(ItemTitle.__table__)).first() is None


def test_valid_titles_seed_referential_and_fill_gaps(conn):
    cep = _insert_item(conn, 309, "Tumeurs du poumon, primitives et secondaires.")
    cnec = _insert_item(conn, 309, "")
    other = _insert_item(conn, 310, None)
    migration.seed_and_backfill(conn)
    titles = _titles(conn)
    assert titles[cep] == "Tumeurs du poumon, primitives et secondaires"
    assert titles[cnec] == "Tumeurs du poumon, primitives et secondaires"
    assert titles[other] is None
    rows = conn.execute(select(ItemTitle.__table__)).all()
    assert [(r.item_number, r.label, r.source, r.occurrences) for r in rows] == [
        (309, "Tumeurs du poumon, primitives et secondaires", "extracted", 1)
    ]


def test_most_frequent_label_wins(conn):
    _insert_item(conn, 1, "Titre minoritaire")
    _insert_item(conn, 1, "Titre majoritaire")
    _insert_item(conn, 1, "Titre majoritaire")
    empty = _insert_item(conn, 1, None)
    migration.seed_and_backfill(conn)
    assert _titles(conn)[empty] == "Titre majoritaire"


def test_idempotent(conn):
    _insert_item(conn, 309, "Tumeurs du poumon, primitives et secondaires")
    _insert_item(conn, 309, None)
    migration.seed_and_backfill(conn)
    first = conn.execute(select(ItemTitle.__table__)).all()
    migration.seed_and_backfill(conn)
    second = conn.execute(select(ItemTitle.__table__)).all()
    assert [(r.item_number, r.label, r.occurrences) for r in first] == [
        (r.item_number, r.label, r.occurrences) for r in second
    ]
