"""token_version sur users (chantier 2, sécurité)

- users.token_version : incrémentée pour révoquer tous les jetons d'une
  utilisatrice ; chaque jeton porte `tv` (version à l'émission).

Revision ID: 020
Revises: 019
Create Date: 2026-09-24
"""

import sqlalchemy as sa

from alembic import op

revision = "020"
down_revision = "019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("token_version", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("users", "token_version")
