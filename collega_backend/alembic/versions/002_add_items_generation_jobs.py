"""add items, generation_jobs tables and colleges.total_pages

Revision ID: 002
Revises: 001
Create Date: 2026-04-27

Story 1.2 — crée les tables items et generation_jobs, ajoute total_pages sur
colleges, et installe le trigger updated_at (reporté depuis Story 1.1).
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Table: items (peuplée par le worker OCR)
    op.create_table(
        "items",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "college_id",
            UUID(as_uuid=True),
            sa.ForeignKey("colleges.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("item_number", sa.Integer(), nullable=False),
        sa.Column("rang", sa.String(1), nullable=False),
        sa.Column("chapter_title", sa.String(500), nullable=True),
        sa.Column("ocr_text", sa.Text(), nullable=True),
        sa.Column(
            "ocr_confidence_score",
            sa.Float(),
            nullable=False,
            server_default=sa.text("0.0"),
        ),
        sa.Column(
            "low_confidence",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("start_page", sa.Integer(), nullable=True),
        sa.Column("end_page", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint("rang IN ('A', 'B', 'C')", name="ck_items_rang"),
    )
    op.create_index("ix_items_college_id", "items", ["college_id"])

    # Table: generation_jobs (suit l'état du pipeline ARQ)
    op.create_table(
        "generation_jobs",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "college_id",
            UUID(as_uuid=True),
            sa.ForeignKey("colleges.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(50),
            nullable=False,
            server_default=sa.text("'pending'"),
        ),
        sa.Column("arq_job_id", sa.String(255), nullable=True),
        sa.Column("card_count", sa.Integer(), server_default=sa.text("0")),
        sa.Column(
            "hash_shared",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("error_message", sa.Text(), nullable=True),
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
    op.create_index("ix_generation_jobs_college_id", "generation_jobs", ["college_id"])

    # Ajouter total_pages sur colleges (nécessaire pour l'endpoint de statut AC#4)
    op.add_column("colleges", sa.Column("total_pages", sa.Integer(), nullable=True))

    # Trigger updated_at sur colleges (reporté depuis Story 1.1 — onupdate SQLAlchemy
    # ne fonctionne pas pour les UPDATE SQL directs, le trigger DB est nécessaire)
    op.execute(
        """
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ language 'plpgsql';
        """
    )
    op.execute(
        """
        CREATE TRIGGER update_colleges_updated_at
            BEFORE UPDATE ON colleges
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS update_colleges_updated_at ON colleges;")
    op.execute("DROP FUNCTION IF EXISTS update_updated_at_column();")
    op.drop_column("colleges", "total_pages")
    op.drop_table("generation_jobs")
    op.drop_table("items")
