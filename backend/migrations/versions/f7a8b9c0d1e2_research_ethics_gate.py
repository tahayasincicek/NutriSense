"""add research ethics gate, consent, idempotency and tidy task fields

Revision ID: f7a8b9c0d1e2
Revises: e6d7f8a9b0c1
Create Date: 2026-07-22
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f7a8b9c0d1e2"
down_revision: Union[str, None] = "e6d7f8a9b0c1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "research_consents",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("participant_pseudonym", sa.String(36), nullable=False),
        sa.Column("protocol_version", sa.String(64), nullable=False),
        sa.Column("consent_version", sa.String(64), nullable=False),
        sa.Column("approval_reference", sa.String(128), nullable=False),
        sa.Column("consent_method", sa.String(32), nullable=False),
        sa.Column("evidence_reference", sa.String(255)),
        sa.Column("witness_reference", sa.String(255)),
        sa.Column("withdrawal_code_hash", sa.String(64), nullable=False),
        sa.Column("data_origin", sa.String(16), nullable=False),
        sa.Column("granted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("withdrawn_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("participant_pseudonym"),
        sa.UniqueConstraint("withdrawal_code_hash"),
    )
    op.create_index(
        "ix_research_consents_participant_pseudonym",
        "research_consents",
        ["participant_pseudonym"],
    )

    with op.batch_alter_table("survey_submissions") as batch_op:
        batch_op.add_column(sa.Column("protocol_version", sa.String(64)))
        batch_op.add_column(sa.Column("approval_reference", sa.String(128)))
        batch_op.add_column(sa.Column("data_origin", sa.String(16)))
        batch_op.add_column(sa.Column("idempotency_key", sa.String(128)))
    op.execute(
        "UPDATE survey_submissions SET protocol_version='legacy-unverified', "
        "approval_reference='legacy-unverified', data_origin='synthetic'"
    )
    with op.batch_alter_table("survey_submissions") as batch_op:
        batch_op.alter_column(
            "protocol_version",
            existing_type=sa.String(64),
            nullable=False,
        )
        batch_op.alter_column(
            "approval_reference",
            existing_type=sa.String(128),
            nullable=False,
        )
        batch_op.alter_column(
            "data_origin",
            existing_type=sa.String(16),
            nullable=False,
        )
        batch_op.create_unique_constraint(
            "uq_survey_participant_idempotency",
            ["participant_pseudonym", "idempotency_key"],
        )

    with op.batch_alter_table("usability_sessions") as batch_op:
        batch_op.add_column(sa.Column("schema_version", sa.String(32)))
        batch_op.add_column(sa.Column("protocol_version", sa.String(64)))
        batch_op.add_column(sa.Column("approval_reference", sa.String(128)))
        batch_op.add_column(sa.Column("data_origin", sa.String(16)))
        batch_op.add_column(sa.Column("idempotency_key", sa.String(128)))
    op.execute(
        "UPDATE usability_sessions SET schema_version='1.0', "
        "protocol_version='legacy-unverified', "
        "approval_reference='legacy-unverified', data_origin='synthetic'"
    )
    with op.batch_alter_table("usability_sessions") as batch_op:
        batch_op.alter_column(
            "schema_version",
            existing_type=sa.String(32),
            nullable=False,
        )
        batch_op.alter_column(
            "protocol_version",
            existing_type=sa.String(64),
            nullable=False,
        )
        batch_op.alter_column(
            "approval_reference",
            existing_type=sa.String(128),
            nullable=False,
        )
        batch_op.alter_column(
            "data_origin",
            existing_type=sa.String(16),
            nullable=False,
        )
        batch_op.create_unique_constraint(
            "uq_usability_participant_idempotency",
            ["participant_pseudonym", "idempotency_key"],
        )

    with op.batch_alter_table("usability_tasks") as batch_op:
        batch_op.add_column(
            sa.Column("error_count", sa.Integer(), nullable=False, server_default="0")
        )
        batch_op.add_column(
            sa.Column("assistance_level", sa.String(32), nullable=False, server_default="none")
        )
        batch_op.add_column(sa.Column("abort_reason", sa.String(255)))
        batch_op.add_column(
            sa.Column("timing_source", sa.String(32), nullable=False, server_default="monotonic")
        )
        batch_op.add_column(
            sa.Column("manually_edited", sa.Boolean(), nullable=False, server_default=sa.false())
        )
        batch_op.add_column(sa.Column("edit_reason", sa.String(255)))


def downgrade() -> None:
    with op.batch_alter_table("usability_tasks") as batch_op:
        for name in (
            "edit_reason",
            "manually_edited",
            "timing_source",
            "abort_reason",
            "assistance_level",
            "error_count",
        ):
            batch_op.drop_column(name)

    with op.batch_alter_table("usability_sessions") as batch_op:
        batch_op.drop_constraint("uq_usability_participant_idempotency", type_="unique")
        for name in (
            "idempotency_key",
            "data_origin",
            "approval_reference",
            "protocol_version",
            "schema_version",
        ):
            batch_op.drop_column(name)

    with op.batch_alter_table("survey_submissions") as batch_op:
        batch_op.drop_constraint("uq_survey_participant_idempotency", type_="unique")
        for name in (
            "idempotency_key",
            "data_origin",
            "approval_reference",
            "protocol_version",
        ):
            batch_op.drop_column(name)

    op.drop_index(
        "ix_research_consents_participant_pseudonym",
        table_name="research_consents",
    )
    op.drop_table("research_consents")
