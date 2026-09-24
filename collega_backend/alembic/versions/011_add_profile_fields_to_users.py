"""Add profile fields to users (first_name, year_group, faculty)

Revision ID: 011
Revises: 010
Create Date: 2026-05-17
"""

import sqlalchemy as sa

from alembic import op

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("first_name", sa.String(100), nullable=True))
    op.add_column("users", sa.Column("year_group", sa.String(50), nullable=True))
    op.add_column("users", sa.Column("faculty", sa.String(150), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "faculty")
    op.drop_column("users", "year_group")
    op.drop_column("users", "first_name")
