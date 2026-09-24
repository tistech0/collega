"""stockage de contenu par empreinte + brouillon d'import (chantier 1)

- ocr_pages / item_texts / item_generations : contenu dédoublonné par empreinte,
  partagé entre collèges (texte OCR conservé avec le collège : NFR9 remplacée).
- job_pages / job_items : brouillon d'un import (reprise OCR, items détectés).
- college_pages : pages en service d'un collège.
- items.text_hash remplace items.ocr_text ; flash_cards.generation_id (origine) ;
  generation_jobs.summary_json remplace page_texts_json.
- Alignement modèles ↔ migrations : index doublon ix_generation_jobs_unique_active
  supprimé (idx_one_active_job_per_college le couvre), card_count NOT NULL.

Revision ID: 018
Revises: 017
Create Date: 2026-09-24
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "018"
down_revision = "017"
branch_labels = None
depends_on = None


def _created_at() -> sa.Column:
    return sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now())


def upgrade() -> None:
    op.create_table(
        "ocr_pages",
        sa.Column("hash", sa.String(64), primary_key=True),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("tables_json", sa.Text(), nullable=False),
        sa.Column("confidence", sa.Float(), nullable=False),
        sa.Column("method", sa.String(20), nullable=False),
        _created_at(),
    )
    op.create_table(
        "item_texts",
        sa.Column("hash", sa.String(64), primary_key=True),
        sa.Column("text", sa.Text(), nullable=False),
        _created_at(),
    )
    op.create_table(
        "item_generations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("text_hash", sa.String(64), sa.ForeignKey("item_texts.hash"), nullable=False),
        sa.Column("generation_version", sa.String(100), nullable=False),
        sa.Column("cards_json", sa.Text(), nullable=False),
        sa.Column("model", sa.String(100), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column("output_tokens", sa.Integer(), nullable=False),
        _created_at(),
        sa.UniqueConstraint("text_hash", "generation_version", name="uq_item_generations_hash_version"),
    )
    op.create_table(
        "job_pages",
        sa.Column("job_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("page_number", sa.Integer(), primary_key=True),
        sa.Column("page_hash", sa.String(64), sa.ForeignKey("ocr_pages.hash"), nullable=False),
    )
    op.create_table(
        "job_items",
        sa.Column("job_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("item_number", sa.Integer(), primary_key=True),
        sa.Column("rang", sa.String(1), nullable=False),
        sa.Column("chapter_title", sa.String(500), nullable=True),
        sa.Column("start_page", sa.Integer(), nullable=True),
        sa.Column("end_page", sa.Integer(), nullable=True),
        sa.Column("ocr_confidence_score", sa.Float(), nullable=False),
        sa.Column("low_confidence", sa.Boolean(), nullable=False),
        sa.Column("text_hash", sa.String(64), sa.ForeignKey("item_texts.hash"), nullable=False),
        sa.Column("generation_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("item_generations.id"), nullable=True),
    )
    op.create_table(
        "college_pages",
        sa.Column("college_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("colleges.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("page_number", sa.Integer(), primary_key=True),
        sa.Column("page_hash", sa.String(64), sa.ForeignKey("ocr_pages.hash"), nullable=False),
    )
    op.add_column("items", sa.Column("text_hash", sa.String(64), sa.ForeignKey("item_texts.hash"), nullable=True))
    op.drop_column("items", "ocr_text")
    op.add_column(
        "flash_cards",
        sa.Column("generation_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("item_generations.id", ondelete="SET NULL"), nullable=True),
    )
    op.add_column("generation_jobs", sa.Column("summary_json", sa.Text(), nullable=True))
    op.drop_column("generation_jobs", "page_texts_json")
    op.drop_index("ix_generation_jobs_unique_active", table_name="generation_jobs")
    op.execute("UPDATE generation_jobs SET card_count = 0 WHERE card_count IS NULL")
    op.alter_column("generation_jobs", "card_count", existing_type=sa.Integer(), nullable=False)


def downgrade() -> None:
    op.alter_column("generation_jobs", "card_count", existing_type=sa.Integer(), nullable=True)
    op.create_index(
        "ix_generation_jobs_unique_active", "generation_jobs", ["college_id"], unique=True,
        postgresql_where=sa.text("status IN ('pending', 'processing')"),
    )
    op.add_column("generation_jobs", sa.Column("page_texts_json", sa.Text(), nullable=True))
    op.drop_column("generation_jobs", "summary_json")
    op.drop_column("flash_cards", "generation_id")
    op.add_column("items", sa.Column("ocr_text", sa.Text(), nullable=True))
    op.drop_column("items", "text_hash")
    for table in ("college_pages", "job_items", "job_pages", "item_generations", "item_texts", "ocr_pages"):
        op.drop_table(table)
