"""Add monthly_reloads_reset_at to users

Revision ID: 007
Revises: 006
Create Date: 2026-05-10
"""

import sqlalchemy as sa

from alembic import op

revision = "007"
down_revision = "006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("monthly_reloads_reset_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "monthly_reloads_reset_at")
