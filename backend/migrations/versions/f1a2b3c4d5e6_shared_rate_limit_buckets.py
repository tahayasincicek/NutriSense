"""shared database rate-limit buckets

Revision ID: f1a2b3c4d5e6
Revises: e0f1a2b3c4d5
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, None] = "e0f1a2b3c4d5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "rate_limit_buckets",
        sa.Column("key_hash", sa.String(length=64), nullable=False),
        sa.Column("action", sa.String(length=32), nullable=False),
        sa.Column("window_started_at", sa.DateTime(), nullable=False),
        sa.Column("request_count", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("key_hash"),
    )
    op.create_index("ix_rate_limit_buckets_action", "rate_limit_buckets", ["action"])
    op.create_index(
        "ix_rate_limit_buckets_window_started_at",
        "rate_limit_buckets",
        ["window_started_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_rate_limit_buckets_window_started_at", table_name="rate_limit_buckets")
    op.drop_index("ix_rate_limit_buckets_action", table_name="rate_limit_buckets")
    op.drop_table("rate_limit_buckets")
