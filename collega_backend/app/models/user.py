import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.college import College
    from app.models.flash_card import FlashCard
    from app.models.generation_job import GenerationJob


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)
    is_beta: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_subscribed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    monthly_reloads: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    apns_token: Mapped[str | None] = mapped_column(String(512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    colleges: Mapped[list["College"]] = relationship(
        "College", back_populates="user", cascade="all, delete-orphan"
    )
    generation_jobs: Mapped[list["GenerationJob"]] = relationship(
        "GenerationJob", back_populates="user", cascade="all, delete-orphan"
    )
    flash_cards: Mapped[list["FlashCard"]] = relationship(
        "FlashCard", back_populates="user", cascade="all, delete-orphan"
    )
