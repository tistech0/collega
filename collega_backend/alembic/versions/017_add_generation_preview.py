"""add generation preview to colleges (story 8.13)

Questions des 3 dernières fiches générées (JSON), diffusées avec l'avancement :
l'écran d'import en cours montre un aperçu des fiches qui arrivent.

Revision ID: 017
Revises: 016
Create Date: 2026-09-23
"""

import sqlalchemy as sa

from alembic import op

revision = "017"
down_revision = "016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("colleges", sa.Column("generation_preview", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("colleges", "generation_preview")
