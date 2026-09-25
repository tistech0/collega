"""Add user_feedback to flash_cards

Revision ID: 008
Revises: 007
Create Date: 2026-05-12
"""

import sqlalchemy as sa

from alembic import op

revision = "008"
down_revision = "007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "flash_cards",
        sa.Column("user_feedback", sa.String(20), nullable=True),
    )
    op.create_check_constraint(
        "ck_flash_cards_user_feedback",
        "flash_cards",
        "user_feedback IN ('positive', 'negative')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_flash_cards_user_feedback", "flash_cards", type_="check")
    op.drop_column("flash_cards", "user_feedback")
