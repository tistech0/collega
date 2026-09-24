"""chantier 4 : rapport de découpage des items, comptabilité des tokens

- generation_jobs.segmentation_report : rapport JSON du découpage (pages → item |
  section | blanche, warnings), écrit en fin d'OCR et affiché dans le détail de job admin.
- claude_usage : une ligne par appel Claude facturé (génération, régénération,
  évaluation). L'historique des jobs y est repris (une ligne `generation` au tarif
  `claude-sonnet-4-6` par job ayant des tokens, datée du job), puis
  generation_jobs.input_tokens/output_tokens sont supprimées.

Revision ID: 021
Revises: 020
Create Date: 2026-09-24
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "021"
down_revision = "020"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("generation_jobs", sa.Column("segmentation_report", sa.Text(), nullable=True))

    op.create_table(
        "claude_usage",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("college_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("colleges.id", ondelete="SET NULL")),
        sa.Column("job_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("generation_jobs.id", ondelete="SET NULL")),
        sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("model", sa.Text(), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column("output_tokens", sa.Integer(), nullable=False),
        sa.CheckConstraint("kind IN ('generation', 'regeneration', 'evaluation')", name="ck_claude_usage_kind"),
    )
    op.create_index("ix_claude_usage_user_id_created_at", "claude_usage", ["user_id", "created_at"])
    op.create_index("ix_claude_usage_job_id", "claude_usage", ["job_id"])

    # Historique : tous les jobs antérieurs ont été générés par Sonnet 4.6.
    op.execute(
        """
        INSERT INTO claude_usage (id, created_at, user_id, college_id, job_id, kind, model, input_tokens, output_tokens)
        SELECT gen_random_uuid(), created_at, user_id, college_id, id, 'generation', 'claude-sonnet-4-6',
               COALESCE(input_tokens, 0), COALESCE(output_tokens, 0)
        FROM generation_jobs
        WHERE COALESCE(input_tokens, 0) > 0 OR COALESCE(output_tokens, 0) > 0
        """
    )
    op.drop_column("generation_jobs", "input_tokens")
    op.drop_column("generation_jobs", "output_tokens")


def downgrade() -> None:
    op.add_column("generation_jobs", sa.Column("input_tokens", sa.Integer(), nullable=True))
    op.add_column("generation_jobs", sa.Column("output_tokens", sa.Integer(), nullable=True))
    # Les tokens de génération reviennent sur leur job ; régénérations, évaluations et
    # appels sans job n'ont pas de colonne où revenir.
    op.execute(
        """
        UPDATE generation_jobs AS j
        SET input_tokens = u.input_tokens, output_tokens = u.output_tokens
        FROM (
            SELECT job_id, SUM(input_tokens) AS input_tokens, SUM(output_tokens) AS output_tokens
            FROM claude_usage
            WHERE kind = 'generation' AND job_id IS NOT NULL
            GROUP BY job_id
        ) AS u
        WHERE j.id = u.job_id
        """
    )
    op.drop_index("ix_claude_usage_job_id", table_name="claude_usage")
    op.drop_index("ix_claude_usage_user_id_created_at", table_name="claude_usage")
    op.drop_table("claude_usage")

    op.drop_column("generation_jobs", "segmentation_report")
