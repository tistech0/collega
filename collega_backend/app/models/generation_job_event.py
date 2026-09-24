import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.generation_job import GenerationJob


class GenerationJobEvent(Base):
    """Événement de timeline persisté pour un GenerationJob (Story 7.7).

    Écrit par le pipeline (ocr_worker / generation_worker / publish) pour
    rendre l'avancement d'un import lisible au refresh, sans fouiller Redis/psql.
    L'écriture est défensive (cf. `record_job_event`) : un échec d'event ne doit
    jamais casser le pipeline.
    """

    __tablename__ = "generation_job_events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    generation_job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("generation_jobs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    page: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    job: Mapped["GenerationJob"] = relationship(
        "GenerationJob", back_populates="events"
    )
