import json
from decimal import Decimal
from pathlib import Path

import pytest

from app.domain.nutrition import NutrientsPer100g, calculate_nutrition, normalize_food_name


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_PATH = Path(__file__).parent / "fixtures" / "nutrition_validation_mvp_v1.json"
ML_CONFIG_PATH = REPOSITORY_ROOT / "ml" / "configs" / "mvp_v1.json"


@pytest.fixture(scope="module")
def validation_data():
    return json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))


def test_validation_inventory_covers_every_frozen_mvp_class(validation_data):
    ml_config = json.loads(ML_CONFIG_PATH.read_text(encoding="utf-8"))
    expected = {item["id"] for item in ml_config["classes"]}
    actual = {item["ml_class_id"] for item in validation_data["records"]}

    assert actual == expected
    assert len(validation_data["records"]) == len(actual)


def test_available_references_are_traceable_and_portion_math_is_exact(validation_data):
    tolerance = Decimal(validation_data["calculation_tolerance"]["absolute_kcal"])
    available = [
        record for record in validation_data["records"]
        if record["validation_status"] == "available"
    ]

    assert len(available) == 7
    for record in available:
        source = validation_data["sources"][record["source_key"]]
        assert record["source_item_id"]
        assert record["source_url"].startswith("https://")
        assert source["license"]
        assert source["attribution"]
        assert Decimal(record["basis_grams"]) == Decimal("100")

        nutrients = NutrientsPer100g(**record["nutrients_per_100g"])
        for scenario in record["portion_scenarios"]:
            result = calculate_nutrition(nutrients, scenario["grams"])
            expected = Decimal(scenario["expected_calories"])
            assert abs(result.calories - expected) <= tolerance


def test_missing_exact_references_never_contain_synthetic_nutrients(validation_data):
    missing = [
        record for record in validation_data["records"]
        if record["validation_status"] == "missing_exact_reference"
    ]

    assert {record["ml_class_id"] for record in missing} == {
        "lahmacun", "mercimek_corbasi", "menemen"
    }
    for record in missing:
        assert record["source_key"] is None
        assert record["nutrients_per_100g"] is None
        assert record["portion_scenarios"] == []
        assert record["notes"]


@pytest.mark.parametrize(
    ("name", "locale", "expected_id"),
    [
        ("French fries", "en-US", "food.french_fries"),
        ("patates kızartması", "tr-TR", "food.french_fries"),
        ("lentil soup", "en-US", "food.mercimek_corbasi"),
        ("mercimek çorbası", "tr-TR", "food.mercimek_corbasi"),
        ("mantı", "tr-TR", "food.manti"),
        ("omelet", "en-US", "food.omelette"),
    ],
)
def test_mvp_names_normalize_to_versioned_canonical_ids(name, locale, expected_id):
    result = normalize_food_name(name, locale)
    assert result.canonical_food_id == expected_id
    assert result.mapped is True


def test_validation_fixture_does_not_claim_a_biological_tolerance(validation_data):
    assert validation_data["biological_tolerance"]["status"] == "not_calibrated"
