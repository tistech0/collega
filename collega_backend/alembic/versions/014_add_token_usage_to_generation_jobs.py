"""add input_tokens / output_tokens to generation_jobs (usage Claude — Story 7.8)

Revision ID: 014
Revises: 013
Create Date: 2026-06-17
"""
from alembic import op
import sqlalchemy as sa

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "generation_jobs",
        sa.Column("input_tokens", sa.Integer(), nullable=True),
    )
    op.add_column(
        "generation_jobs",
        sa.Column("output_tokens", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("generation_jobs", "output_tokens")
    op.drop_column("generation_jobs", "input_tokens")
