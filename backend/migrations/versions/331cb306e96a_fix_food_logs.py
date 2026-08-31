"""fix_food_logs

Revision ID: 331cb306e96a
Revises: a8b9c0d1e2f3
Create Date: 2026-07-27 18:02:59.764918
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '331cb306e96a'
down_revision: Union[str, None] = 'a8b9c0d1e2f3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
