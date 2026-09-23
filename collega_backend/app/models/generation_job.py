import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.college import College
    from app.models.generation_job_event import GenerationJobEvent
    from app.models.user import User


class GenerationJob(Base):
    __tablename__ = "generation_jobs"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'processing', 'ocr_complete', 'generation_complete', 'failed')",
            name="ck_generation_jobs_status",
        ),
        # Un seul import actif par collège (migration 012) : la course de deux imports
        # simultanés se solde par une IntegrityError → 409 JOB_IN_PROGRESS.
        Index(
            "idx_one_active_job_per_college",
            "college_id",
            unique=True,
            postgresql_where=text("status IN ('pending', 'processing', 'ocr_complete')"),
        ),
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
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(50), nullable=False, default="pending"
    )
    arq_job_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    card_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    # Usage Anthropic cumulé sur le job (Story 7.8). NULL = job non mesuré
    # (antérieur migration 014 / échec avant capture) ; 0 = mesuré et gratuit
    # (hash-sharing, Claude jamais appelé). Le coût € est calculé à la lecture.
    input_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    output_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    hash_shared: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    pdf_hash: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Résumé de la bascule (chantier 1) : {changed, added, removed, unchanged, cards, claude_calls, quota_refunded}
    summary_json: Mapped[str | None] = mapped_column(Text, nullable=True)
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

    college: Mapped["College"] = relationship("College", back_populates="generation_jobs")
    user: Mapped["User"] = relationship("User", back_populates="generation_jobs")
    events: Mapped[list["GenerationJobEvent"]] = relationship(
        "GenerationJobEvent", back_populates="job", cascade="all, delete-orphan"
    )
