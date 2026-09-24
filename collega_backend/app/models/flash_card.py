import uuid
from datetime import UTC, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.college import College
    from app.models.item import Item
    from app.models.user import User


class FlashCard(Base):
    __tablename__ = "flash_cards"
    __table_args__ = (
        CheckConstraint("card_type IN ('classique', 'definition', 'cas_clinique')", name="ck_flash_cards_card_type"),
        CheckConstraint("rang IN ('A', 'B', 'C')", name="ck_flash_cards_rang"),
        CheckConstraint(
            "user_feedback IN ('positive', 'negative')",
            name="ck_flash_cards_user_feedback",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id", ondelete="CASCADE"), nullable=False, index=True
    )
    college_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    card_type: Mapped[str] = mapped_column(String(20), nullable=False)
    rang: Mapped[str] = mapped_column(String(1), nullable=False)
    recto: Mapped[str] = mapped_column(Text, nullable=False)
    verso: Mapped[str] = mapped_column(Text, nullable=False)
    ocr_confidence_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    low_confidence: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    user_feedback: Mapped[str | None] = mapped_column(String(20), nullable=True)
    # Sortie Claude d'origine ; NULL = fiche antérieure au chantier 1 ou régénérée par l'utilisatrice.
    generation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("item_generations.id", ondelete="SET NULL"), nullable=True
    )
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

    item: Mapped["Item"] = relationship("Item", back_populates="flash_cards")
    college: Mapped["College"] = relationship("College", back_populates="flash_cards")
    user: Mapped["User"] = relationship("User", back_populates="flash_cards")
