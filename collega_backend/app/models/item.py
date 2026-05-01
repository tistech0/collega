import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.college import College
    from app.models.flash_card import FlashCard


class Item(Base):
    __tablename__ = "items"
    __table_args__ = (
        CheckConstraint("rang IN ('A', 'B', 'C')", name="ck_items_rang"),
        UniqueConstraint("college_id", "item_number", name="uq_items_college_item_number"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    college_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("colleges.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    item_number: Mapped[int] = mapped_column(Integer, nullable=False)
    rang: Mapped[str] = mapped_column(String(1), nullable=False)
    chapter_title: Mapped[str | None] = mapped_column(String(500), nullable=True)
    ocr_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    ocr_confidence_score: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )
    low_confidence: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    start_page: Mapped[int | None] = mapped_column(Integer, nullable=True)
    end_page: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    college: Mapped["College"] = relationship("College", back_populates="items")
    flash_cards: Mapped[list["FlashCard"]] = relationship(
        "FlashCard", back_populates="item", cascade="all, delete-orphan"
    )
