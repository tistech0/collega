"""add item_titles (référentiel partagé des titres d'items — Story 8.0)

Crée le référentiel, écarte les titres faux produits par l'ancien extracteur
(`_CHAPTER_PATTERN` matchait « partie »/« chapitre » dans le corps du texte), sème le
référentiel depuis les titres valides restants, puis complète les items sans titre par
correspondance de numéro. Aucun réimport, aucun appel Claude. Rejouable sans doublon.

Revision ID: 015
Revises: 014
Create Date: 2026-09-22
"""

from collections import Counter
from datetime import UTC, datetime

import sqlalchemy as sa
from sqlalchemy.engine import Connection

from alembic import op
from app.services.ocr.item_titles import clean_title, is_valid_title

revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None

_items = sa.table(
    "items",
    sa.column("id"),
    sa.column("item_number", sa.Integer),
    sa.column("chapter_title", sa.String),
)
_item_titles = sa.table(
    "item_titles",
    sa.column("id", sa.Integer),
    sa.column("item_number", sa.Integer),
    sa.column("label", sa.String),
    sa.column("source", sa.String),
    sa.column("occurrences", sa.Integer),
    sa.column("created_at", sa.DateTime(timezone=True)),
    sa.column("updated_at", sa.DateTime(timezone=True)),
)


def _now() -> datetime:
    return datetime.now(UTC)


def seed_and_backfill(conn: Connection) -> None:
    """Nettoie les titres existants, sème le référentiel, complète les items vides."""
    counts: Counter[tuple[int, str]] = Counter()
    rows = conn.execute(
        sa.select(_items.c.id, _items.c.item_number, _items.c.chapter_title).where(
            _items.c.chapter_title.is_not(None), _items.c.chapter_title != ""
        )
    ).all()
    for item_id, number, raw in rows:
        label = clean_title(raw)
        if not is_valid_title(label):
            conn.execute(_items.update().where(_items.c.id == item_id).values(chapter_title=None))
            continue
        if label != raw:
            conn.execute(_items.update().where(_items.c.id == item_id).values(chapter_title=label))
        counts[(number, label)] += 1

    # Occurrences = nombre d'items portant ce libellé ; un couple déjà présent n'est pas
    # recompté (sinon un second passage compterait les items qu'il vient de compléter).
    for (number, label), count in counts.items():
        existing = conn.execute(
            sa.select(_item_titles.c.id).where(_item_titles.c.item_number == number, _item_titles.c.label == label)
        ).first()
        if existing is None:
            conn.execute(
                _item_titles.insert().values(
                    item_number=number,
                    label=label,
                    source="extracted",
                    occurrences=count,
                    created_at=_now(),
                    updated_at=_now(),
                )
            )

    untitled = (
        conn.execute(
            sa.select(_items.c.item_number)
            .where(sa.or_(_items.c.chapter_title.is_(None), _items.c.chapter_title == ""))
            .distinct()
        )
        .scalars()
        .all()
    )
    for number in untitled:
        best = conn.execute(
            sa.select(_item_titles.c.label)
            .where(_item_titles.c.item_number == number)
            .order_by(
                sa.case((_item_titles.c.source == "official", 0), else_=1),
                _item_titles.c.occurrences.desc(),
                _item_titles.c.id.asc(),
            )
            .limit(1)
        ).scalar_one_or_none()
        if best is not None:
            conn.execute(
                _items.update()
                .where(_items.c.item_number == number)
                .where(sa.or_(_items.c.chapter_title.is_(None), _items.c.chapter_title == ""))
                .values(chapter_title=best)
            )


def upgrade() -> None:
    op.create_table(
        "item_titles",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("item_number", sa.Integer(), nullable=False),
        sa.Column("label", sa.String(200), nullable=False),
        sa.Column("source", sa.String(16), nullable=False, server_default="extracted"),
        sa.Column("occurrences", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("item_number", "label", name="uq_item_titles_number_label"),
        sa.CheckConstraint("source IN ('extracted', 'official')", name="ck_item_titles_source"),
    )
    op.create_index("ix_item_titles_item_number", "item_titles", ["item_number"])
    seed_and_backfill(op.get_bind())


def downgrade() -> None:
    op.drop_index("ix_item_titles_item_number", table_name="item_titles")
    op.drop_table("item_titles")
