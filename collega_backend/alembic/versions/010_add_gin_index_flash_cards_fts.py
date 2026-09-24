"""Add GIN full-text search index on flash_cards

Revision ID: 010
Revises: 009
Create Date: 2026-05-16
"""

from alembic import op

revision = "010"
down_revision = "009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # CONCURRENTLY ne peut pas s'exécuter dans une transaction Alembic
    op.execute("COMMIT")
    op.execute("""
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flash_cards_fts
        ON flash_cards
        USING GIN (to_tsvector('french', coalesce(recto, '') || ' ' || coalesce(verso, '')))
    """)


def downgrade() -> None:
    op.execute("COMMIT")
    op.execute("DROP INDEX CONCURRENTLY IF EXISTS idx_flash_cards_fts")
