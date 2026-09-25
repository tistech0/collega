from datetime import UTC, datetime

from sqlalchemy import CheckConstraint, DateTime, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ItemTitle(Base):
    """Référentiel partagé numéro d'item ECN → libellé (story 8.0).

    Alimenté par l'extraction à chaque import (source `extracted`) ; une liste
    officielle pourra s'y injecter plus tard (source `official`, prioritaire).
    Une ligne par numéro et par libellé observé, avec un compteur d'occurrences.
    """

    __tablename__ = "item_titles"
    __table_args__ = (
        UniqueConstraint("item_number", "label", name="uq_item_titles_number_label"),
        CheckConstraint("source IN ('extracted', 'official')", name="ck_item_titles_source"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    item_number: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    label: Mapped[str] = mapped_column(String(200), nullable=False)
    source: Mapped[str] = mapped_column(String(16), nullable=False, default="extracted")
    occurrences: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
