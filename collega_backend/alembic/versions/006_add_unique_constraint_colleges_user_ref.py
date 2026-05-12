"""add unique constraint colleges user_id + college_ref_id

Revision ID: 006
Revises: 005
Create Date: 2026-05-08
"""
from alembic import op

revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_colleges_user_ref_id",
        "colleges",
        ["user_id", "college_ref_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_colleges_user_ref_id", "colleges", type_="unique")
