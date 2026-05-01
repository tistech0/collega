import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.flash_card import FlashCard
    from app.models.generation_job import GenerationJob
    from app.models.item import Item
    from app.models.user import User


class CollegeStatus(str, Enum):
    pending = "pending"
    processing = "processing"
    ocr_complete = "ocr_complete"
    generation_complete = "generation_complete"
    failed = "failed"


class College(Base):
    __tablename__ = "colleges"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    college_ref_id: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(
        String(50), nullable=False, default=CollegeStatus.pending
    )
    reload_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    ocr_page_progress: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_pages: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    user: Mapped["User"] = relationship("User", back_populates="colleges")
    items: Mapped[list["Item"]] = relationship(
        "Item", back_populates="college", cascade="all, delete-orphan"
    )
    generation_jobs: Mapped[list["GenerationJob"]] = relationship(
        "GenerationJob", back_populates="college", cascade="all, delete-orphan"
    )
    flash_cards: Mapped[list["FlashCard"]] = relationship(
        "FlashCard", back_populates="college", cascade="all, delete-orphan"
    )
