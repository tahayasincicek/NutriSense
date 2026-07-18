import json
from pathlib import Path

import pytest

from app.domain.nutrition import NutritionDomainError
from app.services.nutritionix_service import NutritionixService


FIXTURE = Path(__file__).parent / "fixtures" / "nutritionix_apple.json"


def service_without_init() -> NutritionixService:
    service = NutritionixService.__new__(NutritionixService)
    service._available = False
    service._local_meta = {}
    service._local_db = {}
    service._local_verified = False
    return service


def test_fixture_is_normalized_with_complete_provenance_and_no_rounding():
    service = service_without_init()
    api_food = json.loads(FIXTURE.read_text(encoding="utf-8"))

    result = service._format_result(api_food, 150, input_locale="en-US")

    assert result["available"] is True
    assert result["canonical_food_id"] == "food.apple"
    assert result["normalization_version"] == "tr-en-canonical-v1"
    assert result["total_calories"] == pytest.approx(78.0)
    assert result["portion_method"] == "user_selected"
    assert result["portion_is_estimate"] is False
    assert result["provenance"]["source_item_id"].startswith("common:apple")
    assert result["provenance"]["serving_grams"] == 182.0
    assert result["provenance"]["license_name"]
    assert result["provenance"]["attribution"]


def test_unverified_prototype_json_is_not_a_successful_fallback():
    service = service_without_init()
    service._local_db = {"elma": {"calories_per_100g": 52}}

    result = service._query_local_db("elma", None, input_locale="tr-TR")

    assert result["available"] is False
    assert result["source"] == "not_found"
    assert "total_calories" not in result
    assert result["provenance"] is None


@pytest.mark.parametrize("portion", [0, -10, float("nan"), float("inf"), 2001])
def test_provider_adapter_rejects_unsafe_portions(portion):
    service = service_without_init()
    api_food = json.loads(FIXTURE.read_text(encoding="utf-8"))

    with pytest.raises(NutritionDomainError):
        service._format_result(api_food, portion, input_locale="en-US")


def test_provider_zero_calorie_cannot_be_formatted_as_success():
    service = service_without_init()
    api_food = json.loads(FIXTURE.read_text(encoding="utf-8"))
    api_food["nf_calories"] = 0

    with pytest.raises(NutritionDomainError):
        service._format_result(api_food, None, input_locale="en-US")
