"""init users and colleges tables

Revision ID: 001
Revises:
Create Date: 2026-04-27

Story 1.1 — crée uniquement les tables users et colleges.
Les tables items, flash_cards, generation_jobs sont créées dans les Stories 1.2 et 1.3.
"""

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("hashed_password", sa.String(), nullable=False),
        sa.Column("is_beta", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("is_subscribed", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("monthly_reloads", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("apns_token", sa.String(512), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_table(
        "colleges",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("college_ref_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(50), nullable=False, server_default=sa.text("'pending'")),
        sa.Column("reload_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("ocr_page_progress", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index("ix_colleges_user_id", "colleges", ["user_id"])


def downgrade() -> None:
    op.drop_table("colleges")
    op.drop_table("users")
