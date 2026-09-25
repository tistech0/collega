"""Réglages applicatifs modifiables à chaud (chantier 5, R4) : une ligne par clé."""

from datetime import datetime
from typing import Any

from sqlalchemy import JSON, DateTime, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AppSetting(Base):
    __tablename__ = "app_settings"

    key: Mapped[str] = mapped_column(Text, primary_key=True)
    # JSONB en Postgres, JSON en SQLite (tests).
    value: Mapped[Any] = mapped_column(JSON().with_variant(JSONB(), "postgresql"), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
