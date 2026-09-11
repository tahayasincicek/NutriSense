"""drop adult age confirmation; registration has no age question

Revision ID: c8d9e0f1a2b3
Revises: b7c8d9e0f1a2
Create Date: 2026-09-11
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c8d9e0f1a2b3"
down_revision: Union[str, None] = "b7c8d9e0f1a2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_column("users", "adult_confirmed_at")


def downgrade() -> None:
    op.add_column(
        "users",
        sa.Column("adult_confirmed_at", sa.DateTime(), nullable=True),
    )
