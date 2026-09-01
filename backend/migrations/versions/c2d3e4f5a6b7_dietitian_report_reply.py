"""dietitian report reply

Diyetisyenin rapora yazdığı cevap. Hasta rapora not/soru ekleyebiliyordu ama
akış tek yönlüydü; cevap alanı döngüyü tamamlar.

Revision ID: c2d3e4f5a6b7
Revises: b1c2d3e4f5a6
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c2d3e4f5a6b7"
down_revision: Union[str, None] = "b1c2d3e4f5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("dietitian_reports") as batch:
        batch.add_column(sa.Column("dietitian_reply", sa.Text(), nullable=True))
        batch.add_column(
            sa.Column("dietitian_replied_at", sa.DateTime(), nullable=True)
        )


def downgrade() -> None:
    with op.batch_alter_table("dietitian_reports") as batch:
        batch.drop_column("dietitian_replied_at")
        batch.drop_column("dietitian_reply")
