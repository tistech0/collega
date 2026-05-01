"""add flash_cards table and pdf_hash on generation_jobs

Revision ID: 004
Revises: 003
Create Date: 2026-04-28
"""
from alembic import op
import sqlalchemy as sa

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "flash_cards",
        sa.Column("id", sa.UUID(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("item_id", sa.UUID(), nullable=False),
        sa.Column("college_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("card_type", sa.String(20), nullable=False),
        sa.Column("rang", sa.String(1), nullable=False),
        sa.Column("recto", sa.Text(), nullable=False),
        sa.Column("verso", sa.Text(), nullable=False),
        sa.Column("ocr_confidence_score", sa.Float(), nullable=False, server_default="0.0"),
        sa.Column("low_confidence", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["item_id"], ["items.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["college_id"], ["colleges.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.CheckConstraint("card_type IN ('classique', 'definition')", name="ck_flash_cards_card_type"),
        sa.CheckConstraint("rang IN ('A', 'B', 'C')", name="ck_flash_cards_rang"),
    )

    op.create_index("ix_flash_cards_item_id", "flash_cards", ["item_id"])
    op.create_index("ix_flash_cards_college_id", "flash_cards", ["college_id"])
    op.create_index("ix_flash_cards_user_id", "flash_cards", ["user_id"])

    op.execute(
        """
        CREATE TRIGGER update_flash_cards_updated_at
            BEFORE UPDATE ON flash_cards
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        """
    )

    op.add_column(
        "generation_jobs",
        sa.Column("pdf_hash", sa.String(64), nullable=True),
    )
    op.create_index("ix_generation_jobs_pdf_hash", "generation_jobs", ["pdf_hash"])


def downgrade() -> None:
    op.drop_index("ix_generation_jobs_pdf_hash", table_name="generation_jobs")
    op.drop_column("generation_jobs", "pdf_hash")
    op.execute("DROP TRIGGER IF EXISTS update_flash_cards_updated_at ON flash_cards;")
    op.drop_index("ix_flash_cards_user_id", table_name="flash_cards")
    op.drop_index("ix_flash_cards_college_id", table_name="flash_cards")
    op.drop_index("ix_flash_cards_item_id", table_name="flash_cards")
    op.drop_table("flash_cards")
