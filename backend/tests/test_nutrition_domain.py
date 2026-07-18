from datetime import datetime, timezone
from decimal import Decimal

import pytest
from hypothesis import given, strategies as st

from app.domain.nutrition import (
    NutritionDomainError,
    NutritionProvenance,
    NutritionSourceKind,
    NutrientsPer100g,
    UnitConversion,
    calculate_nutrition,
    normalize_food_name,
    portion_to_grams,
    validate_portion_grams,
)


def test_calculation_keeps_full_precision_and_records_macro_delta():
    profile = NutrientsPer100g(
        calories=Decimal("52"),
        protein=Decimal("0.26"),
        carbs=Decimal("13.81"),
        fat=Decimal("0.17"),
        fiber=Decimal("2.4"),
    )

    result = calculate_nutrition(profile, Decimal("150"))

    assert result.calories == Decimal("78")
    assert result.carbs == Decimal("20.715")
    assert result.macro_calories == Decimal("86.715")
    assert result.macro_calorie_delta == Decimal("8.715")
    assert result.macro_calorie_delta_percent == Decimal("11.17307692307692307692307692")


@given(
    st.decimals(
        min_value="0.01", max_value="2000", places=4,
        allow_nan=False, allow_infinity=False,
    )
)
def test_calories_scale_linearly_for_every_safe_portion(portion):
    profile = NutrientsPer100g(
        calories=Decimal("131"), protein=Decimal("5"),
        carbs=Decimal("25"), fat=Decimal("1.1"), fiber=Decimal("1.8")
    )
    result = calculate_nutrition(profile, portion)
    assert result.calories == Decimal("131") * portion / Decimal("100")


@pytest.mark.parametrize("unsafe", [0, -1, 2000.01, float("nan"), float("inf"), "NaN"])
def test_unsafe_portions_are_rejected(unsafe):
    with pytest.raises(NutritionDomainError):
        validate_portion_grams(unsafe)


def test_pasta_collision_is_resolved_by_locale_and_canonical_id():
    english = normalize_food_name("pasta", "en-US")
    turkish = normalize_food_name("pasta", "tr-TR")

    assert english.canonical_food_id == "food.pasta"
    assert english.food_name_tr == "Makarna"
    assert turkish.canonical_food_id == "food.cake"
    assert turkish.food_name_tr == "Pasta"


def test_non_gram_unit_requires_food_specific_sourced_conversion():
    conversion = UnitConversion(
        canonical_food_id="food.bread",
        unit="dilim",
        grams_per_unit=Decimal("25"),
        source_item_id="example-reference-id",
        source_name="test fixture",
    )
    conversions = {("food.bread", "dilim"): conversion}

    assert portion_to_grams(
        value=2, unit="dilim", canonical_food_id="food.bread", conversions=conversions
    ) == Decimal("50")
    with pytest.raises(NutritionDomainError):
        portion_to_grams(
            value=1, unit="kase", canonical_food_id="food.bread", conversions=conversions
        )


def test_provenance_rejects_missing_license_or_naive_timestamp():
    with pytest.raises(NutritionDomainError):
        NutritionProvenance(
            source=NutritionSourceKind.NUTRITIONIX,
            source_item_id="item-1",
            locale="tr-TR",
            retrieved_at=datetime.now(),
            serving_unit="gram",
            serving_grams=Decimal("100"),
            license_name="",
            attribution="Nutritionix",
        )

    valid = NutritionProvenance(
        source=NutritionSourceKind.USER_ENTERED,
        source_item_id="user-entry-1",
        locale="tr-TR",
        retrieved_at=datetime.now(timezone.utc),
        serving_unit="gram",
        serving_grams=Decimal("100"),
        license_name="Kullanıcı beyanı",
        attribution="Kullanıcı tarafından girildi",
    )
    assert valid.source == NutritionSourceKind.USER_ENTERED


def test_zero_calorie_profile_cannot_be_a_successful_food_result():
    with pytest.raises(NutritionDomainError):
        NutrientsPer100g(
            calories=Decimal("0"), protein=Decimal("0"),
            carbs=Decimal("0"), fat=Decimal("0"), fiber=Decimal("0")
        )
