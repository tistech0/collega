"""chantier 4 : rapport de découpage des items

- generation_jobs.segmentation_report : rapport JSON du découpage (pages → item |
  section | blanche, warnings), écrit en fin d'OCR et affiché dans le détail de job admin.

Revision ID: 021
Revises: 019
Create Date: 2026-09-24
"""

import sqlalchemy as sa

from alembic import op

revision = "021"
# 020 existera sur main au moment de la fusion : down_revision sera alors corrigé.
down_revision = "019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("generation_jobs", sa.Column("segmentation_report", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("generation_jobs", "segmentation_report")
