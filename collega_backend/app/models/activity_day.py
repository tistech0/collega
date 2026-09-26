"""Résumé quotidien d'activité envoyé par l'app (console de pilotage de la beta).

Une ligne par utilisatrice et par jour local de l'app : l'app renvoie toujours le
total du jour, la ligne est remplacée (jamais additionnée)."""

import uuid
from datetime import UTC, date, datetime

from sqlalchemy import Boolean, CheckConstraint, Date, DateTime, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ActivityDay(Base):
    __tablename__ = "activity_days"
    __table_args__ = (
        CheckConstraint("cards_reviewed >= 0", name="ck_activity_days_cards_reviewed"),
        CheckConstraint("streak >= 0", name="ck_activity_days_streak"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    day: Mapped[date] = mapped_column(Date, primary_key=True)
    cards_reviewed: Mapped[int] = mapped_column(Integer, nullable=False)
    session_completed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    streak: Mapped[int] = mapped_column(Integer, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
