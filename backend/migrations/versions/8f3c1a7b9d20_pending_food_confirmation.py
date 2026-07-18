"""add pending food analysis confirmation fields

Revision ID: 8f3c1a7b9d20
Revises: 18797ee84f1b
Create Date: 2026-07-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import app.models.database


revision: str = "8f3c1a7b9d20"
down_revision: Union[str, None] = "18797ee84f1b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("recognition_attempts") as batch_op:
        batch_op.add_column(sa.Column("capture_id", sa.String(length=36), nullable=True))
        batch_op.add_column(sa.Column("analysis_payload", sa.JSON(), nullable=True))
        batch_op.add_column(sa.Column("decision", sa.String(length=16), nullable=True))
        batch_op.add_column(sa.Column("expires_at", app.models.database.UTCDateTime(), nullable=True))
        batch_op.add_column(sa.Column("decided_at", app.models.database.UTCDateTime(), nullable=True))
        batch_op.create_unique_constraint(
            "uq_recognition_user_capture", ["user_id", "capture_id"]
        )


def downgrade() -> None:
    with op.batch_alter_table("recognition_attempts") as batch_op:
        batch_op.drop_constraint("uq_recognition_user_capture", type_="unique")
        batch_op.drop_column("decided_at")
        batch_op.drop_column("expires_at")
        batch_op.drop_column("decision")
        batch_op.drop_column("analysis_payload")
        batch_op.drop_column("capture_id")
