import uuid
from datetime import UTC, datetime
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

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)
    is_beta: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_subscribed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    first_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    year_group: Mapped[str | None] = mapped_column(String(50), nullable=True)
    faculty: Mapped[str | None] = mapped_column(String(150), nullable=True)
    monthly_reloads: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    monthly_reloads_reset_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    apns_token: Mapped[str | None] = mapped_column(String(512), nullable=True)
    reminder_hour_utc: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Incrémentée pour révoquer tous les jetons émis (réutilisation d'un refresh,
    # mot de passe réinitialisé) : un jeton dont `tv` est inférieur est refusé.
    token_version: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    # Horodatage du dernier événement RevenueCat appliqué : un événement plus ancien est ignoré.
    subscription_event_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    colleges: Mapped[list["College"]] = relationship("College", back_populates="user", cascade="all, delete-orphan")
    generation_jobs: Mapped[list["GenerationJob"]] = relationship(
        "GenerationJob", back_populates="user", cascade="all, delete-orphan"
    )
    flash_cards: Mapped[list["FlashCard"]] = relationship(
        "FlashCard", back_populates="user", cascade="all, delete-orphan"
    )
