"""add partial unique index on generation_jobs to enforce one active job per college

Revision ID: 012
Revises: 011
Create Date: 2026-05-20
"""
import logging

import sqlalchemy as sa
from alembic import op

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None

logger = logging.getLogger(__name__)


_ACTIVE_STATUSES = "('pending', 'processing', 'ocr_complete')"


def upgrade() -> None:
    # Defensive cleanup : si des jobs actifs en doublon existent déjà (mode pre-atomique),
    # garder le plus ancien et supprimer les autres — sinon CREATE UNIQUE INDEX échoue.
    conn = op.get_bind()
    dialect = conn.dialect.name
    # Tie-break sur `id` quand `created_at` est strictement égal (possible à la
    # microseconde près sur insertions concurrentes) — sinon les deux doublons
    # survivent au DELETE et CREATE UNIQUE INDEX échoue.
    if dialect == "postgresql":
        cleanup_sql = sa.text(
            f"""
            DELETE FROM generation_jobs g1
            USING generation_jobs g2
            WHERE g1.id != g2.id
              AND g1.college_id = g2.college_id
              AND g1.status IN {_ACTIVE_STATUSES}
              AND g2.status IN {_ACTIVE_STATUSES}
              AND (
                  g1.created_at > g2.created_at
                  OR (g1.created_at = g2.created_at AND g1.id > g2.id)
              )
            """
        )
    else:
        cleanup_sql = sa.text(
            f"""
            DELETE FROM generation_jobs
            WHERE id IN (
                SELECT g1.id
                FROM generation_jobs g1
                JOIN generation_jobs g2
                  ON g1.college_id = g2.college_id
                 AND g1.id != g2.id
                WHERE g1.status IN {_ACTIVE_STATUSES}
                  AND g2.status IN {_ACTIVE_STATUSES}
                  AND (
                      g1.created_at > g2.created_at
                      OR (g1.created_at = g2.created_at AND g1.id > g2.id)
                  )
            )
            """
        )

    result = conn.execute(cleanup_sql)
    deleted = getattr(result, "rowcount", None)
    if deleted:
        logger.warning(
            "Pre-index cleanup: deleted %d duplicate active GenerationJob rows", deleted
        )

    op.create_index(
        "idx_one_active_job_per_college",
        "generation_jobs",
        ["college_id"],
        unique=True,
        postgresql_where=sa.text(f"status IN {_ACTIVE_STATUSES}"),
        sqlite_where=sa.text(f"status IN {_ACTIVE_STATUSES}"),
    )


def downgrade() -> None:
    op.drop_index("idx_one_active_job_per_college", table_name="generation_jobs")
