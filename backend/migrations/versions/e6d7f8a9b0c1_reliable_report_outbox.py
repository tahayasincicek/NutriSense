"""add reliable dietitian report outbox and consent evidence

Revision ID: e6d7f8a9b0c1
Revises: d5c9e2f4a6b7
Create Date: 2026-07-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e6d7f8a9b0c1"
down_revision: Union[str, None] = "d5c9e2f4a6b7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


old_report_status = sa.Enum(
    "pending", "sent", "failed", name="report_status_enum",
)
new_report_status = sa.Enum(
    "pending", "queued", "sending", "sent", "partial_failed", "failed",
    name="report_status_enum",
)
old_delivery_status = sa.Enum(
    "sent", "failed", "skipped", name="notification_status_enum",
)
new_delivery_status = sa.Enum(
    "queued", "sending", "sent", "failed", "skipped",
    name="notification_status_enum",
)


def upgrade() -> None:
    with op.batch_alter_table("consent_records") as batch_op:
        batch_op.add_column(sa.Column("context_hash", sa.String(64)))
        batch_op.add_column(sa.Column("channels_json", sa.JSON()))
        batch_op.add_column(sa.Column("record_count", sa.Integer()))
        batch_op.add_column(sa.Column("date_from", sa.Date()))
        batch_op.add_column(sa.Column("date_to", sa.Date()))
        batch_op.add_column(sa.Column("recipient_masked", sa.JSON()))
        batch_op.add_column(sa.Column("request_id", sa.String(64)))
        batch_op.create_index("ix_consent_records_context_hash", ["context_hash"])
        batch_op.create_index("ix_consent_records_request_id", ["request_id"])

    with op.batch_alter_table("dietitian_reports") as batch_op:
        batch_op.add_column(sa.Column("request_id", sa.String(64)))
        batch_op.add_column(sa.Column(
            "consent_context_hash", sa.String(64), nullable=False,
            server_default="legacy-unverified",
        ))
        batch_op.add_column(sa.Column(
            "channels_json", sa.JSON(), nullable=False, server_default="[]",
        ))
        batch_op.add_column(sa.Column(
            "recipient_snapshot_json", sa.JSON(), nullable=False,
            server_default="{}",
        ))
        batch_op.add_column(sa.Column(
            "payload_json", sa.JSON(), nullable=False, server_default="{}",
        ))
        batch_op.add_column(sa.Column(
            "record_count", sa.Integer(), nullable=False, server_default="0",
        ))
        batch_op.add_column(sa.Column("completed_at", sa.DateTime(timezone=True)))
        batch_op.create_index("ix_dietitian_reports_request_id", ["request_id"])

    with op.batch_alter_table("dietitian_reports") as batch_op:
        batch_op.alter_column(
            "status", existing_type=old_report_status,
            type_=new_report_status, existing_nullable=False,
            server_default="queued",
        )
    op.execute("UPDATE dietitian_reports SET status = 'queued' WHERE status = 'pending'")

    with op.batch_alter_table("notification_deliveries") as batch_op:
        batch_op.add_column(sa.Column("provider_status", sa.String(64)))
        batch_op.add_column(sa.Column("error_message", sa.String(255)))
        batch_op.add_column(sa.Column(
            "destination_masked", sa.String(255), nullable=False,
            server_default="legacy-masked",
        ))
        batch_op.add_column(sa.Column(
            "attempt_count", sa.Integer(), nullable=False, server_default="0",
        ))
        batch_op.add_column(sa.Column(
            "max_attempts", sa.Integer(), nullable=False, server_default="3",
        ))
        batch_op.add_column(sa.Column("next_attempt_at", sa.DateTime(timezone=True)))
        batch_op.add_column(sa.Column("sent_at", sa.DateTime(timezone=True)))
        batch_op.create_index(
            "ix_notification_deliveries_next_attempt_at", ["next_attempt_at"],
        )
        batch_op.alter_column(
            "attempted_at", existing_type=sa.DateTime(timezone=True),
            nullable=True,
        )
        batch_op.alter_column(
            "status", existing_type=old_delivery_status,
            type_=new_delivery_status, existing_nullable=False,
            server_default="queued",
        )


def downgrade() -> None:
    op.execute(
        "UPDATE dietitian_reports SET status = 'failed' "
        "WHERE status IN ('queued', 'sending', 'partial_failed')"
    )
    op.execute(
        "UPDATE notification_deliveries SET status = 'failed' "
        "WHERE status IN ('queued', 'sending')"
    )
    with op.batch_alter_table("notification_deliveries") as batch_op:
        batch_op.alter_column(
            "status", existing_type=new_delivery_status,
            type_=old_delivery_status, existing_nullable=False,
        )
        batch_op.alter_column(
            "attempted_at", existing_type=sa.DateTime(timezone=True),
            nullable=False,
        )
        batch_op.drop_index("ix_notification_deliveries_next_attempt_at")
        for column in (
            "sent_at", "next_attempt_at", "max_attempts", "attempt_count",
            "destination_masked", "error_message", "provider_status",
        ):
            batch_op.drop_column(column)

    with op.batch_alter_table("dietitian_reports") as batch_op:
        batch_op.alter_column(
            "status", existing_type=new_report_status,
            type_=old_report_status, existing_nullable=False,
        )
        batch_op.drop_index("ix_dietitian_reports_request_id")
        for column in (
            "completed_at", "record_count", "payload_json",
            "recipient_snapshot_json", "channels_json",
            "consent_context_hash", "request_id",
        ):
            batch_op.drop_column(column)

    with op.batch_alter_table("consent_records") as batch_op:
        batch_op.drop_index("ix_consent_records_request_id")
        batch_op.drop_index("ix_consent_records_context_hash")
        for column in (
            "request_id", "recipient_masked", "date_to", "date_from",
            "record_count", "channels_json", "context_hash",
        ):
            batch_op.drop_column(column)
