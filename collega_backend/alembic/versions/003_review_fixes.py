"""review fixes — contraintes, triggers, index unique, page_texts_json

Revision ID: 003
Revises: 002
Create Date: 2026-04-27

Corrections issues de la revue de code de Story 1.2 :
- CHECK constraint sur generation_jobs.status
- Trigger updated_at sur generation_jobs
- Index unique partiel pour éviter les jobs concurrents par college
- Contrainte UNIQUE (college_id, item_number) sur items
- Colonne page_texts_json sur generation_jobs (reprise OCR correcte)
"""
from alembic import op
import sqlalchemy as sa


revision = "003"
down_revision = "002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Colonne page_texts_json pour stocker les textes OCR accumulés (reprise fine)
    op.add_column(
        "generation_jobs",
        sa.Column("page_texts_json", sa.Text(), nullable=True),
    )

    # CHECK constraint sur generation_jobs.status — valeurs valides du pipeline
    op.execute(
        """
        ALTER TABLE generation_jobs
        ADD CONSTRAINT ck_generation_jobs_status
        CHECK (status IN ('pending', 'processing', 'ocr_complete', 'generation_complete', 'failed'));
        """
    )

    # Trigger updated_at sur generation_jobs (la fonction existe depuis 002)
    op.execute(
        """
        CREATE TRIGGER update_generation_jobs_updated_at
            BEFORE UPDATE ON generation_jobs
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        """
    )

    # Index unique partiel — un seul job actif (pending/processing) par college à la fois
    op.execute(
        """
        CREATE UNIQUE INDEX ix_generation_jobs_unique_active
        ON generation_jobs(college_id)
        WHERE status IN ('pending', 'processing');
        """
    )

    # Contrainte UNIQUE (college_id, item_number) — pas de doublon d'item par college
    op.create_unique_constraint(
        "uq_items_college_item_number",
        "items",
        ["college_id", "item_number"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_items_college_item_number", "items", type_="unique")
    op.execute("DROP INDEX IF EXISTS ix_generation_jobs_unique_active;")
    op.execute("DROP TRIGGER IF EXISTS update_generation_jobs_updated_at ON generation_jobs;")
    op.execute(
        "ALTER TABLE generation_jobs DROP CONSTRAINT IF EXISTS ck_generation_jobs_status;"
    )
    op.drop_column("generation_jobs", "page_texts_json")
