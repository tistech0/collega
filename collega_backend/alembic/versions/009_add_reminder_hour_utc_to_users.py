"""Add reminder_hour_utc to users

Revision ID: 009
Revises: 008
Create Date: 2026-05-16
"""
from alembic import op
import sqlalchemy as sa

revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("reminder_hour_utc", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "reminder_hour_utc")
