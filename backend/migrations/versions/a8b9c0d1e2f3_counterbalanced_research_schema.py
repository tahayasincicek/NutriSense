"""add counterbalanced condition fields and full survey instrument metadata

Revision ID: a8b9c0d1e2f3
Revises: f7a8b9c0d1e2
Create Date: 2026-07-22
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a8b9c0d1e2f3"
down_revision: Union[str, None] = "f7a8b9c0d1e2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


SURVEY_SCHEMA = {
    "instrument_version": "NS-SURVEY-1.0-DRAFT",
    "status": "investigator-developed-draft",
    "scale_direction": "higher-is-more-positive-for-q2-q3-q4-q8",
    "questions": [
        {"id": "q1", "type": "multiChoice", "scored": False},
        {"id": "q2", "type": "likert", "range": [1, 5]},
        {"id": "q3", "type": "likert", "range": [1, 5]},
        {"id": "q4", "type": "likert", "range": [1, 5]},
        {"id": "q5", "type": "yesNo", "scored": False},
        {"id": "q6", "type": "openText", "pii_warning": True},
        {"id": "q7", "type": "openText", "pii_warning": True},
        {"id": "q8", "type": "starRating", "range": [1, 5]},
    ],
}


def _survey_versions():
    return sa.table(
        "survey_versions",
        sa.column("version", sa.String(32)),
        sa.column("schema_json", sa.JSON()),
    )


def upgrade() -> None:
    with op.batch_alter_table("usability_sessions") as batch_op:
        batch_op.add_column(sa.Column("counterbalance_sequence", sa.String(2)))
    with op.batch_alter_table("usability_tasks") as batch_op:
        batch_op.add_column(
            sa.Column(
                "condition",
                sa.String(32),
                nullable=False,
                server_default="nutrisense",
            )
        )
    versions = _survey_versions()
    op.get_bind().execute(
        versions.update().where(versions.c.version == "1.0").values(
            schema_json=SURVEY_SCHEMA
        )
    )


def downgrade() -> None:
    versions = _survey_versions()
    op.get_bind().execute(
        versions.update().where(versions.c.version == "1.0").values(
            schema_json={"seed": "system-survey-definition"}
        )
    )
    with op.batch_alter_table("usability_tasks") as batch_op:
        batch_op.drop_column("condition")
    with op.batch_alter_table("usability_sessions") as batch_op:
        batch_op.drop_column("counterbalance_sequence")
