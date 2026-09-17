"""pending verified e-mail changes

Revision ID: f2b3c4d5e6f7
Revises: f1a2b3c4d5e6
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f2b3c4d5e6f7"
down_revision: Union[str, None] = "f1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pending_email_changes",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("new_email", sa.String(length=255), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("attempt_count", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_pending_email_changes_user_id", "pending_email_changes", ["user_id"], unique=True,
    )
    op.create_index(
        "ix_pending_email_changes_new_email", "pending_email_changes", ["new_email"], unique=True,
    )
    op.create_index(
        "ix_pending_email_changes_expires_at", "pending_email_changes", ["expires_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_pending_email_changes_expires_at", table_name="pending_email_changes")
    op.drop_index("ix_pending_email_changes_new_email", table_name="pending_email_changes")
    op.drop_index("ix_pending_email_changes_user_id", table_name="pending_email_changes")
    op.drop_table("pending_email_changes")
