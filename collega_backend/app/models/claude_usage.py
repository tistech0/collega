import uuid
from datetime import UTC, datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base

USAGE_KINDS = ("generation", "regeneration", "evaluation")


class ClaudeUsage(Base):
    """Un appel Claude facturé (chantier 4, spec § 6) : écrit juste après la réponse,
    même si le job échoue ou si la réponse est inutilisable. Le coût € n'est jamais
    stocké : il est calculé à la lecture depuis le modèle et les tokens."""

    __tablename__ = "claude_usage"
    __table_args__ = (
        CheckConstraint("kind IN ('generation', 'regeneration', 'evaluation')", name="ck_claude_usage_kind"),
        Index("ix_claude_usage_user_id_created_at", "user_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=lambda: datetime.now(UTC), server_default=func.now()
    )
    # Liens conservés tant que la cible existe : compte, collège ou job supprimé → NULL,
    # la ligne reste dans les totaux.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    college_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="SET NULL"), nullable=True
    )
    job_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("generation_jobs.id", ondelete="SET NULL"), nullable=True, index=True
    )
    kind: Mapped[str] = mapped_column(Text, nullable=False)
    model: Mapped[str] = mapped_column(Text, nullable=False)
    input_tokens: Mapped[int] = mapped_column(Integer, nullable=False)
    output_tokens: Mapped[int] = mapped_column(Integer, nullable=False)
