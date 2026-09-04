"""Danışan başına birden çok beslenme notu.

Not tekil kayıttan listeye dönüyor: her kayıt eskisinin üzerine yazmak
yerine ayrı satır olarak birikiyor. Bunun için çift başına tekillik
kısıtı kalkar, listeyi sıralayan bileşik indeks eklenir.

Revision ID: f5a6b7c8d9e0
Revises: e4f5a6b7c8d9
"""

from typing import Sequence, Union

from alembic import op

revision: str = "f5a6b7c8d9e0"
down_revision: Union[str, None] = "e4f5a6b7c8d9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Bilesik indeks once eklenir: MySQL, yabanci anahtarin dayandigi tek
    # kalan indeksi dusurmeye izin vermez.
    op.create_index(
        "ix_dietitian_notes_pair_created",
        "dietitian_notes",
        ["user_id", "dietitian_id", "created_at"],
    )
    op.drop_constraint(
        "uq_note_user_dietitian", "dietitian_notes", type_="unique"
    )


def downgrade() -> None:
    # Tekillige donmek icin cift basina en yeni not disindakiler silinir;
    # aksi halde kisit eklenemez.
    op.execute(
        """
        DELETE n FROM dietitian_notes n
        JOIN dietitian_notes newer
          ON newer.user_id = n.user_id
         AND newer.dietitian_id = n.dietitian_id
         AND newer.created_at > n.created_at
        """
    )
    op.create_unique_constraint(
        "uq_note_user_dietitian",
        "dietitian_notes",
        ["user_id", "dietitian_id"],
    )
    op.drop_index("ix_dietitian_notes_pair_created", "dietitian_notes")
