"""Diyetisyenin danışan için tuttuğu kalıcı beslenme notu.

Rapor cevabı tek bir gönderime bağlıdır; bu not danışanın geneline aittir.
Danışan-diyetisyen çifti başına tek not tutulur, güncellenerek kullanılır.

Revision ID: e4f5a6b7c8d9
Revises: d3e4f5a6b7c8
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e4f5a6b7c8d9"
down_revision: Union[str, None] = "d3e4f5a6b7c8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "dietitian_notes",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("dietitian_id", sa.String(length=36), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["dietitian_id"], ["dietitians.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "dietitian_id", name="uq_note_user_dietitian"
        ),
    )
    op.create_index(
        "ix_dietitian_notes_user_id", "dietitian_notes", ["user_id"]
    )
    op.create_index(
        "ix_dietitian_notes_dietitian_id", "dietitian_notes", ["dietitian_id"]
    )


def downgrade() -> None:
    # MySQL, yabanci anahtarin dayandigi indeksi tek basina dusurmeye izin
    # vermez; tablo dusunce indeksler de gider.
    op.drop_table("dietitian_notes")
