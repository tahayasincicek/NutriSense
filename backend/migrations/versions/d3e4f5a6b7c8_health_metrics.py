"""health metrics and weight measurements

Su, adım, uyku, ruh hâli ve kilo ölçümleri yalnız cihazda tutuluyordu; uygulama
silinince kayboluyordu. Ölçümler artık hesaba bağlı olarak saklanır.

Revision ID: d3e4f5a6b7c8
Revises: c2d3e4f5a6b7
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d3e4f5a6b7c8"
down_revision: Union[str, None] = "c2d3e4f5a6b7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "health_metrics",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("log_date", sa.Date(), nullable=False),
        sa.Column("water_ml", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("steps", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("sleep_hours", sa.Float(), nullable=False, server_default="0"),
        sa.Column("mood", sa.String(length=32), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "log_date", name="uq_health_metric_user_day"),
    )
    op.create_index("ix_health_metrics_user_id", "health_metrics", ["user_id"])
    op.create_index("ix_health_metrics_log_date", "health_metrics", ["log_date"])

    op.create_table(
        "weight_measurements",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("measured_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_weight_measurements_user_id", "weight_measurements", ["user_id"]
    )
    op.create_index(
        "ix_weight_measurements_measured_at", "weight_measurements", ["measured_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_weight_measurements_measured_at", "weight_measurements")
    op.drop_index("ix_weight_measurements_user_id", "weight_measurements")
    op.drop_table("weight_measurements")
    op.drop_index("ix_health_metrics_log_date", "health_metrics")
    op.drop_index("ix_health_metrics_user_id", "health_metrics")
    op.drop_table("health_metrics")
