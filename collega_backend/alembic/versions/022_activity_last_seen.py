"""console de pilotage : users.last_seen_at et activity_days

Revision ID: 022
Revises: 021
Create Date: 2026-09-26
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "022"
down_revision = "021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "activity_days",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("day", sa.Date(), primary_key=True),
        sa.Column("cards_reviewed", sa.Integer(), nullable=False),
        sa.Column("session_completed", sa.Boolean(), nullable=False),
        sa.Column("streak", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("cards_reviewed >= 0", name="ck_activity_days_cards_reviewed"),
        sa.CheckConstraint("streak >= 0", name="ck_activity_days_streak"),
    )


def downgrade() -> None:
    op.drop_table("activity_days")
    op.drop_column("users", "last_seen_at")
