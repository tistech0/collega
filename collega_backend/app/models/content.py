"""Stockage de contenu adressé par empreinte + brouillon d'import (chantier 1).

- `ocr_pages`, `item_texts`, `item_generations` : contenu partagé, dédoublonné
  par empreinte ; purgé quand plus aucun collège ni import ne le référence.
- `job_pages`, `job_items` : brouillon d'un import (reprise OCR, items détectés),
  vidé à la bascule ou à l'échec.
- `college_pages` : pages en service d'un collège.
"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint, false, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class OcrPage(Base):
    __tablename__ = "ocr_pages"

    hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    tables_json: Mapped[str] = mapped_column(Text, nullable=False)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    method: Mapped[str] = mapped_column(String(20), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class ItemText(Base):
    __tablename__ = "item_texts"

    hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class ItemGeneration(Base):
    __tablename__ = "item_generations"
    __table_args__ = (UniqueConstraint("text_hash", "generation_version", name="uq_item_generations_hash_version"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    text_hash: Mapped[str] = mapped_column(String(64), ForeignKey("item_texts.hash"), nullable=False)
    generation_version: Mapped[str] = mapped_column(String(100), nullable=False)
    cards_json: Mapped[str] = mapped_column(Text, nullable=False)
    model: Mapped[str] = mapped_column(String(100), nullable=False)
    input_tokens: Mapped[int] = mapped_column(Integer, nullable=False)
    output_tokens: Mapped[int] = mapped_column(Integer, nullable=False)
    # Claude a jugé le texte sans vrai contenu d'enseignement : 0 fiche, conservée
    # comme une autre génération (un réimport ne repaie pas l'item).
    insufficient_text: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=false())
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class JobPage(Base):
    __tablename__ = "job_pages"

    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True
    )
    page_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    page_hash: Mapped[str] = mapped_column(String(64), ForeignKey("ocr_pages.hash"), nullable=False)


class JobItem(Base):
    __tablename__ = "job_items"

    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True
    )
    item_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    rang: Mapped[str] = mapped_column(String(1), nullable=False)
    chapter_title: Mapped[str | None] = mapped_column(String(500), nullable=True)
    start_page: Mapped[int | None] = mapped_column(Integer, nullable=True)
    end_page: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ocr_confidence_score: Mapped[float] = mapped_column(Float, nullable=False)
    low_confidence: Mapped[bool] = mapped_column(Boolean, nullable=False)
    text_hash: Mapped[str] = mapped_column(String(64), ForeignKey("item_texts.hash"), nullable=False)
    generation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("item_generations.id"), nullable=True
    )
    # Génération « texte insuffisant » : item listé dans le résumé d'import.
    insufficient_text: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=false())


class CollegePage(Base):
    __tablename__ = "college_pages"

    college_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), primary_key=True
    )
    page_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    page_hash: Mapped[str] = mapped_column(String(64), ForeignKey("ocr_pages.hash"), nullable=False)
