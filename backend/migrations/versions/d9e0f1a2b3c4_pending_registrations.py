"""verify e-mail ownership before opening an account

Revision ID: d9e0f1a2b3c4
Revises: c8d9e0f1a2b3
Create Date: 2026-09-15
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d9e0f1a2b3c4"
down_revision: Union[str, None] = "c8d9e0f1a2b3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pending_registrations",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("phone", sa.String(20)),
        sa.Column("daily_calorie_target", sa.Float(), nullable=False),
        sa.Column("code_hash", sa.String(64), nullable=False),
        sa.Column("attempt_count", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_pending_registrations_email", "pending_registrations", ["email"], unique=True
    )
    op.create_index(
        "ix_pending_registrations_expires_at", "pending_registrations", ["expires_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_pending_registrations_expires_at", table_name="pending_registrations")
    op.drop_index("ix_pending_registrations_email", table_name="pending_registrations")
    op.drop_table("pending_registrations")
