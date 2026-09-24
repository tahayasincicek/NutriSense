"""Expand consent policy version for published notice identifiers.

Revision ID: f3c4d5e6f7a8
Revises: f2b3c4d5e6f7
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql


revision = "f3c4d5e6f7a8"
down_revision = "f2b3c4d5e6f7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("consent_records") as batch_op:
        batch_op.alter_column(
            "policy_version",
            existing_type=sa.String(length=32),
            type_=sa.String(length=128),
            existing_nullable=False,
        )
    if op.get_bind().dialect.name == "mysql":
        op.alter_column(
            "consent_records", "granted_at",
            existing_type=mysql.DATETIME(),
            type_=mysql.DATETIME(fsp=6),
            existing_nullable=False,
        )
        op.alter_column(
            "weight_measurements", "measured_at",
            existing_type=mysql.DATETIME(),
            type_=mysql.DATETIME(fsp=6),
            existing_nullable=False,
        )


def downgrade() -> None:
    if op.get_bind().dialect.name == "mysql":
        op.alter_column(
            "weight_measurements", "measured_at",
            existing_type=mysql.DATETIME(fsp=6),
            type_=mysql.DATETIME(),
            existing_nullable=False,
        )
        op.alter_column(
            "consent_records", "granted_at",
            existing_type=mysql.DATETIME(fsp=6),
            type_=mysql.DATETIME(),
            existing_nullable=False,
        )
    with op.batch_alter_table("consent_records") as batch_op:
        batch_op.alter_column(
            "policy_version",
            existing_type=sa.String(length=128),
            type_=sa.String(length=32),
            existing_nullable=False,
        )
