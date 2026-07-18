"""add confirmed editable and recoverable food log lifecycle

Revision ID: d5c9e2f4a6b7
Revises: c4b8a1d2e3f4
Create Date: 2026-07-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d5c9e2f4a6b7"
down_revision: Union[str, None] = "c4b8a1d2e3f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("food_logs") as batch_op:
        batch_op.add_column(sa.Column(
            "original_food_name", sa.String(255), nullable=True,
        ))
        batch_op.add_column(sa.Column(
            "original_food_name_tr", sa.String(255), nullable=True,
        ))
        batch_op.add_column(sa.Column(
            "is_user_confirmed", sa.Boolean(), nullable=False,
            server_default=sa.true(),
        ))
        batch_op.add_column(sa.Column(
            "is_corrected", sa.Boolean(), nullable=False,
            server_default=sa.false(),
        ))
        batch_op.add_column(sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=True,
        ))
        batch_op.add_column(sa.Column(
            "deleted_at", sa.DateTime(timezone=True), nullable=True,
        ))
        batch_op.create_index(
            "ix_food_logs_is_user_confirmed", ["is_user_confirmed"], unique=False,
        )
        batch_op.create_index(
            "ix_food_logs_deleted_at", ["deleted_at"], unique=False,
        )

    op.execute("UPDATE food_logs SET updated_at = logged_at WHERE updated_at IS NULL")
    with op.batch_alter_table("food_logs") as batch_op:
        batch_op.alter_column(
            "updated_at", existing_type=sa.DateTime(timezone=True), nullable=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("food_logs") as batch_op:
        batch_op.drop_index("ix_food_logs_deleted_at")
        batch_op.drop_index("ix_food_logs_is_user_confirmed")
        for column in (
            "deleted_at", "updated_at", "is_corrected", "is_user_confirmed",
            "original_food_name_tr", "original_food_name",
        ):
            batch_op.drop_column(column)
