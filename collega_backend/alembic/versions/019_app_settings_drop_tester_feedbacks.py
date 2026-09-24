"""suppression de la table tester_feedbacks (chantier 5)

- tester_feedbacks : le testeur web est supprimé (R1) ; les avis passent par
  flash_cards.user_feedback. La table est exportée en CSV avant la migration
  (scripts/export_tester_feedbacks.py), puis supprimée (R2).

Revision ID: 019
Revises: 018
Create Date: 2026-09-24
"""

import sqlalchemy as sa

from alembic import op

revision = "019"
down_revision = "018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_index("ix_tester_feedbacks_college_id", table_name="tester_feedbacks")
    op.drop_index("ix_tester_feedbacks_flash_card_id", table_name="tester_feedbacks")
    op.drop_table("tester_feedbacks")


def downgrade() -> None:
    # Recrée la table telle que définie par la migration 005 (données non restaurées).
    op.create_table(
        "tester_feedbacks",
        sa.Column("id", sa.UUID(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("flash_card_id", sa.UUID(), nullable=False),
        sa.Column("college_id", sa.UUID(), nullable=False),
        sa.Column("tester_id", sa.String(100), nullable=False),
        sa.Column("is_pertinent", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["flash_card_id"], ["flash_cards.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["college_id"], ["colleges.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("flash_card_id", "tester_id", name="uq_tester_feedbacks_card_tester"),
    )
    op.create_index("ix_tester_feedbacks_flash_card_id", "tester_feedbacks", ["flash_card_id"])
    op.create_index("ix_tester_feedbacks_college_id", "tester_feedbacks", ["college_id"])
