"""store dietitian data processing agreement acceptance

Revision ID: a1b2c3d4e5f6
Revises: f5a6b7c8d9e0
Create Date: 2026-09-11
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "f5a6b7c8d9e0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "dietitians",
        sa.Column("data_processing_agreement_version", sa.String(64), nullable=True),
    )
    op.add_column(
        "dietitians",
        sa.Column("data_processing_agreement_accepted_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("dietitians", "data_processing_agreement_accepted_at")
    op.drop_column("dietitians", "data_processing_agreement_version")
