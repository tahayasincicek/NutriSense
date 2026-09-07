"""Real catalog arithmetic and fail-closed provenance regression checks."""

from copy import deepcopy
import json
from pathlib import Path

import pytest

from app.domain.nutrition import NutritionDomainError
from app.services import nutritionix_service as module
from app.services.nutritionix_service import NutritionixService


CATALOG_PATH = Path(module.__file__).resolve().parents[1] / "data/verified_nutrition.json"


@pytest.fixture
def catalog_service():
    payload = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    service = NutritionixService.__new__(NutritionixService)
    service._available = False
    service._local_verified = True
    service._local_meta = payload.pop("_meta")
    service._local_db = payload
    return service


@pytest.mark.parametrize("name,kcal", [
    ("baklava", 440), ("hamburger", 288), ("pizza", 266),
    ("omlet", 143), ("PATATES KIZARTMASI", 198),
])
@pytest.mark.parametrize("grams", [50, 100, 150, 200])
def test_official_catalog_portions_and_provenance(catalog_service, name, kcal, grams):
    result = catalog_service._query_local_db(name, grams, input_locale="tr-TR")
    assert result["available"] is True
    assert result["total_calories"] == pytest.approx(kcal * grams / 100)
    assert result["provenance"]["source_item_id"].startswith("usda-fdc:")
    assert "https://fdc.nal.usda.gov/" in result["provenance"]["attribution"]
    assert result["portion_is_estimate"] is False
    assert result["portion_conversions"] == []  # No fabricated item/bowl weights.


def test_source_default_is_explicitly_an_estimate_and_variant_is_named(catalog_service):
    result = catalog_service._query_local_db("omlet", None, input_locale="tr-TR")
    assert result["portion_is_estimate"] is True
    assert result["estimated_portion_g"] == 100
    assert result["food_name_tr"] == "Omlet (ilave yağsız)"
    again = catalog_service._query_local_db(result["food_name_tr"], 150, input_locale="tr-TR")
    assert again["total_calories"] == pytest.approx(214.5)


@pytest.mark.parametrize("field", [
    "evidence_status", "source_item_id", "protein_per_100g", "carbs_per_100g",
    "fat_per_100g", "fiber_per_100g", "calories_per_100g", "default_portion_g",
])
def test_incomplete_record_never_becomes_verified(catalog_service, field):
    del catalog_service._local_db["baklava"][field]
    result = catalog_service._query_local_db("baklava", None)
    assert result["available"] is False
    assert result["provenance"] is None
    assert "total_calories" not in result
    assert catalog_service._query_local_db("hamburger", None)["available"] is True


@pytest.mark.parametrize("field,value", [
    ("attribution", "Mock Data"), ("license", "Local"), ("source_url", ""),
    ("source_url", "http://example.com"), ("source_item_name", ""),
    ("retrieved_at", "invalid"), ("retrieved_at", "2026-01-01"),
])
def test_invalid_provenance_is_rejected(catalog_service, field, value):
    source_id = catalog_service._local_db["baklava"]["source_item_id"]
    catalog_service._local_meta["source_inventory"][source_id][field] = value
    assert catalog_service._query_local_db("baklava", None)["available"] is False


def test_missing_source_inventory_entry_is_not_filled_with_mock(catalog_service):
    catalog_service._local_meta["source_inventory"].clear()
    assert catalog_service._query_local_db("baklava", None)["available"] is False


@pytest.mark.parametrize("value", [None, True, "NaN", "Infinity", -1])
def test_invalid_nutrients_are_rejected(catalog_service, value):
    catalog_service._local_db["baklava"]["protein_per_100g"] = value
    assert catalog_service._query_local_db("baklava", None)["available"] is False


def test_unproven_unit_weight_is_not_returned(catalog_service):
    catalog_service._local_db["baklava"]["portion_units"] = [{"unit": "adet", "grams_per_unit": 50}]
    assert catalog_service._query_local_db("baklava", None)["available"] is False


@pytest.mark.asyncio
async def test_search_filters_unverified_records_and_normalizes_turkish(catalog_service):
    catalog_service._local_db["baklava"]["evidence_status"] = "UNVERIFIED"
    assert await catalog_service.search_foods("baklava") == []
    assert await catalog_service.search_foods("PATATES KIZARTMASI") == [
        {"food_name": "french_fries", "photo": ""},
    ]


@pytest.mark.parametrize("name", ["mantı", "menemen", "lahmacun", "bilinmeyen yemek"])
def test_no_silent_substitution_for_unsupported_food(catalog_service, name):
    assert catalog_service._query_local_db(name, None)["available"] is False


def test_bad_json_override_does_not_crash_startup(tmp_path, monkeypatch):
    path = tmp_path / "broken.json"
    path.write_text("{invalid", encoding="utf-8")
    monkeypatch.setattr(module, "LOCAL_DB_PATH", path)
    service = NutritionixService()
    assert service._query_local_db("baklava", None)["available"] is False


def test_packaged_catalog_loads_without_external_volume(monkeypatch):
    monkeypatch.delenv("CALORIE_DB_PATH", raising=False)
    monkeypatch.setattr(module, "LOCAL_DB_PATH", module._resolve_local_db_path())
    monkeypatch.setattr(module.settings, "nutrition_provider_mode", "verified_local")
    service = NutritionixService()
    assert service._query_local_db("baklava", 50)["total_calories"] == 220


@pytest.mark.parametrize("field", ["nf_calories", "nf_protein", "nf_total_carbohydrate", "nf_total_fat", "nf_dietary_fiber"])
@pytest.mark.parametrize("mutation", ["missing", "null", "boolean"])
@pytest.mark.asyncio
async def test_incomplete_provider_response_does_not_invent_zero(catalog_service, field, mutation, monkeypatch):
    food = json.loads((Path(__file__).parent / "fixtures/nutritionix_apple.json").read_text())
    if mutation == "missing":
        del food[field]
    else:
        food[field] = None if mutation == "null" else True

    async def provider(_):
        return deepcopy(food)

    catalog_service._available = True
    monkeypatch.setattr(catalog_service, "_query_api", provider)
    result = await catalog_service.get_nutrition("apple")
    assert result["available"] is False
    assert "total_calories" not in result


def test_invalid_user_portion_still_raises(catalog_service):
    with pytest.raises(NutritionDomainError):
        catalog_service._query_local_db("baklava", 0)


def test_real_catalog_search_portion_confirm_preserves_source(client, catalog_service, monkeypatch):
    from app.main import app
    from app.middleware.auth import get_current_user
    from app.models.database import FoodLog, NutritionSource, SessionLocal, User
    from app.routers import food_router

    with SessionLocal() as db:
        user = User(email="catalog@example.invalid", hashed_password="unused", full_name="Catalog Test")
        db.add(user)
        db.commit()
        db.refresh(user)
        user_id = user.id
        app.dependency_overrides[get_current_user] = lambda: user
    monkeypatch.setattr(food_router, "nutrition_service", catalog_service)
    try:
        search = client.get("/api/v1/food/search", params={"query": "omlet"})
        assert search.status_code == 200, search.text
        analysis = search.json()
        assert analysis["provenance"]["source_item_id"] == "usda-fdc:2707205"
        assert analysis["needs_confirmation"] is True
        assert "ilave yağsız" in analysis["tts_text"]
        with SessionLocal() as db:
            assert db.query(FoodLog).filter_by(user_id=user_id).count() == 0

        analysis_id = analysis["analysis_id"]
        portion = client.post(f"/api/v1/food-analysis/{analysis_id}/portion", json={
            "portion_value": 150, "portion_unit": "gram", "portion_method": "user_selected",
        })
        assert portion.status_code == 200, portion.text
        assert portion.json()["total_calories"] == pytest.approx(214.5)
        decision = client.post(f"/api/v1/food-analysis/{analysis_id}/decision", json={"action": "confirm"})
        assert decision.status_code == 200, decision.text
        with SessionLocal() as db:
            log = db.query(FoodLog).filter_by(user_id=user_id).one()
            assert float(log.total_calories) == pytest.approx(214.5)
            assert db.query(NutritionSource).filter_by(source_item_id="usda-fdc:2707205").count() == 1

        unsupported = client.get("/api/v1/food/search", params={"query": "mantı"})
        assert unsupported.status_code == 404
        with SessionLocal() as db:
            assert db.query(FoodLog).filter_by(user_id=user_id).count() == 1
    finally:
        app.dependency_overrides.pop(get_current_user, None)
