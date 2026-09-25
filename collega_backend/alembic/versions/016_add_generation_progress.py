"""add generation progress to colleges (story 8.13)

Avancement de la génération des fiches, publié item par item pendant la
génération (session séparée) et diffusé par le flux SSE : l'écran d'import en
cours montre « N fiches prêtes » au fil de l'eau.

Revision ID: 016
Revises: 015
Create Date: 2026-09-23
"""

import sqlalchemy as sa

from alembic import op

revision = "016"
down_revision = "015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("colleges", sa.Column("generation_items_done", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("colleges", sa.Column("generation_items_total", sa.Integer(), nullable=True))
    op.add_column("colleges", sa.Column("generation_cards", sa.Integer(), nullable=False, server_default="0"))


def downgrade() -> None:
    op.drop_column("colleges", "generation_cards")
    op.drop_column("colleges", "generation_items_total")
    op.drop_column("colleges", "generation_items_done")
