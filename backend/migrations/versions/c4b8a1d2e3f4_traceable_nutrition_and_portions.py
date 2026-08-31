"""add traceable nutrition provenance and explicit portions

Revision ID: c4b8a1d2e3f4
Revises: 8f3c1a7b9d20
Create Date: 2026-07-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c4b8a1d2e3f4"
down_revision: Union[str, None] = "8f3c1a7b9d20"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


NUMERIC = sa.Numeric(precision=14, scale=6)


def upgrade() -> None:
    with op.batch_alter_table("nutrition_sources") as batch_op:
        batch_op.add_column(sa.Column(
            "canonical_food_id", sa.String(255), nullable=False,
            server_default="food.legacy.unmapped",
        ))
        batch_op.add_column(sa.Column(
            "source_item_id", sa.String(255), nullable=False,
            server_default="legacy-unverified",
        ))
        batch_op.add_column(sa.Column(
            "locale", sa.String(16), nullable=False, server_default="und",
        ))
        batch_op.add_column(sa.Column(
            "serving_unit", sa.String(64), nullable=False, server_default="gram",
        ))
        batch_op.add_column(sa.Column(
            "serving_grams", NUMERIC, nullable=False, server_default="100",
        ))
        batch_op.add_column(sa.Column(
            "license_name", sa.String(255), nullable=False,
            server_default="UNVERIFIED LEGACY",
        ))
        # MySQL rejects defaults on TEXT columns. Add nullable, backfill, then
        # enforce NOT NULL in a separate portable operation.
        batch_op.add_column(sa.Column(
            "attribution", sa.Text(), nullable=True,
        ))
        batch_op.add_column(sa.Column(
            "normalization_version", sa.String(64), nullable=False,
            server_default="legacy-unmapped",
        ))
        batch_op.alter_column(
            "calories_per_100g", existing_type=sa.Float(), type_=NUMERIC,
            existing_nullable=False,
        )

    nutrition_sources = sa.table(
        "nutrition_sources",
        sa.column("attribution", sa.Text()),
    )
    op.execute(
        nutrition_sources.update()
        .where(nutrition_sources.c.attribution.is_(None))
        .values(attribution="Legacy record; source unavailable")
    )
    with op.batch_alter_table("nutrition_sources") as batch_op:
        batch_op.alter_column(
            "attribution",
            existing_type=sa.Text(),
            nullable=False,
            existing_nullable=True,
        )

    with op.batch_alter_table("food_logs") as batch_op:
        batch_op.add_column(sa.Column(
            "canonical_food_id", sa.String(255), nullable=False,
            server_default="food.legacy.unmapped",
        ))
        batch_op.add_column(sa.Column(
            "portion_value", NUMERIC, nullable=False, server_default="100",
        ))
        batch_op.add_column(sa.Column(
            "portion_unit", sa.String(16), nullable=False, server_default="gram",
        ))
        batch_op.add_column(sa.Column(
            "portion_method", sa.String(32), nullable=False,
            server_default="legacy_unknown",
        ))
        batch_op.add_column(sa.Column(
            "portion_is_estimate", sa.Boolean(), nullable=False,
            server_default=sa.true(),
        ))
        batch_op.add_column(sa.Column(
            "macro_calories", NUMERIC, nullable=False, server_default="0",
        ))
        batch_op.add_column(sa.Column(
            "macro_calorie_delta", NUMERIC, nullable=False, server_default="0",
        ))
        batch_op.add_column(sa.Column(
            "nutrition_reliability", sa.String(32), nullable=False,
            server_default="unverified",
        ))
        for column in (
            "calories_per_100g", "estimated_portion_g", "total_calories",
            "protein", "carbs", "fat", "fiber",
        ):
            batch_op.alter_column(
                column, existing_type=sa.Float(), type_=NUMERIC,
                existing_nullable=False,
            )


def downgrade() -> None:
    with op.batch_alter_table("food_logs") as batch_op:
        for column in (
            "calories_per_100g", "estimated_portion_g", "total_calories",
            "protein", "carbs", "fat", "fiber",
        ):
            batch_op.alter_column(
                column, existing_type=NUMERIC, type_=sa.Float(),
                existing_nullable=False,
            )
        for column in (
            "nutrition_reliability", "macro_calorie_delta", "macro_calories",
            "portion_is_estimate", "portion_method", "portion_unit",
            "portion_value", "canonical_food_id",
        ):
            batch_op.drop_column(column)

    with op.batch_alter_table("nutrition_sources") as batch_op:
        batch_op.alter_column(
            "calories_per_100g", existing_type=NUMERIC, type_=sa.Float(),
            existing_nullable=False,
        )
        for column in (
            "normalization_version", "attribution", "license_name",
            "serving_grams", "serving_unit", "locale", "source_item_id",
            "canonical_food_id",
        ):
            batch_op.drop_column(column)
