"""dietitian mutual consent

Eşleşme artık iki taraflı onayla kurulur: hasta sağlık verisinin
paylaşılmasına rıza gösterir, diyetisyen de hastayı kabul eder. Bağ yalnız
iki onay da tamamlandığında 'approved' olur.

Mevcut approved kayıtlar geriye dönük olarak diyetisyence kabul edilmiş
sayılır; aksi halde çalışan eşleşmeler sessizce kopardı.

Revision ID: b1c2d3e4f5a6
Revises: a9b0c1d2e3f4
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b1c2d3e4f5a6"
down_revision: Union[str, None] = "a9b0c1d2e3f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_STATUS_WITH_REJECTED = sa.Enum(
    "pending", "approved", "cancelled", "rejected", name="assignment_status_enum"
)
_STATUS_WITHOUT_REJECTED = sa.Enum(
    "pending", "approved", "cancelled", name="assignment_status_enum"
)


def upgrade() -> None:
    with op.batch_alter_table("dietitian_assignments") as batch:
        batch.add_column(sa.Column("dietitian_accepted_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("rejected_at", sa.DateTime(), nullable=True))
        batch.alter_column(
            "status",
            existing_type=_STATUS_WITHOUT_REJECTED,
            type_=_STATUS_WITH_REJECTED,
            existing_nullable=False,
        )

    # Zaten kurulmuş bağların kopmaması için geriye dönük kabul damgası.
    op.execute(
        "UPDATE dietitian_assignments "
        "SET dietitian_accepted_at = approved_at "
        "WHERE status = 'approved' AND approved_at IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("UPDATE dietitian_assignments SET status = 'cancelled' WHERE status = 'rejected'")
    with op.batch_alter_table("dietitian_assignments") as batch:
        batch.alter_column(
            "status",
            existing_type=_STATUS_WITH_REJECTED,
            type_=_STATUS_WITHOUT_REJECTED,
            existing_nullable=False,
        )
        batch.drop_column("rejected_at")
        batch.drop_column("dietitian_accepted_at")
