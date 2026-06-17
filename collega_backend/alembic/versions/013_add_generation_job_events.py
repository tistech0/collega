"""add generation_job_events table (timeline persistée des imports — Story 7.7)

Revision ID: 013
Revises: 012
Create Date: 2026-06-17
"""
from alembic import op
import sqlalchemy as sa

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "generation_job_events",
        sa.Column("id", sa.UUID(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("generation_job_id", sa.UUID(), nullable=False),
        sa.Column("event_type", sa.String(50), nullable=False),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("page", sa.Integer(), nullable=True),
        sa.Column("total", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["generation_job_id"], ["generation_jobs.id"], ondelete="CASCADE"),
    )
    op.create_index(
        "ix_generation_job_events_generation_job_id",
        "generation_job_events",
        ["generation_job_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_generation_job_events_generation_job_id",
        table_name="generation_job_events",
    )
    op.drop_table("generation_job_events")
