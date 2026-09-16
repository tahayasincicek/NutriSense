"""verify dietitian registrations with the e-mailed code

Revision ID: e0f1a2b3c4d5
Revises: d9e0f1a2b3c4
Create Date: 2026-09-16
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e0f1a2b3c4d5"
down_revision: Union[str, None] = "d9e0f1a2b3c4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "pending_registrations",
        sa.Column("account_type", sa.String(16), nullable=False, server_default="patient"),
    )
    op.add_column(
        "pending_registrations",
        sa.Column("specialization", sa.String(255), nullable=True),
    )
    op.add_column(
        "pending_registrations",
        sa.Column("data_processing_agreement_version", sa.String(64), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("pending_registrations", "data_processing_agreement_version")
    op.drop_column("pending_registrations", "specialization")
    op.drop_column("pending_registrations", "account_type")
