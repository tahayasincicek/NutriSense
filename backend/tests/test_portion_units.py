"""Porsiyon birimleri: hacim ve sayılabilir birimler grama doğru çevrilir."""

from decimal import Decimal

import pytest

from app.domain.nutrition import (
    NutritionDomainError,
    UnitConversion,
    portion_to_grams,
)


def _conversion(unit: str, grams_per_unit: str) -> UnitConversion:
    return UnitConversion(
        canonical_food_id="food.ayran",
        unit=unit,
        grams_per_unit=Decimal(grams_per_unit),
        source_item_id="local_mock",
        source_name="Yerel doğrulanmış tablo",
    )


def _table(*conversions: UnitConversion) -> dict:
    return {(c.canonical_food_id, c.unit): c for c in conversions}


def test_millilitres_use_the_food_density_not_one_to_one():
    # Ayran suyun biraz üstünde yoğunlukta; 250 ml 250 gram değildir.
    table = _table(_conversion("ml", "1.03"))
    grams = portion_to_grams(
        value=250, unit="ml", canonical_food_id="food.ayran", conversions=table
    )
    assert grams == Decimal("257.5")


def test_litre_scales_a_thousand_times_the_millilitre():
    table = _table(_conversion("litre", "1030"))
    grams = portion_to_grams(
        value=1, unit="litre", canonical_food_id="food.ayran", conversions=table
    )
    assert grams == Decimal("1030")


def test_volume_limit_is_not_the_count_limit():
    # Sayılabilir birimlerdeki 20 tavanı hacimde uygulansaydı bir bardak su
    # bile kaydedilemezdi.
    table = _table(_conversion("ml", "1"))
    grams = portion_to_grams(
        value=500, unit="ml", canonical_food_id="food.ayran", conversions=table
    )
    assert grams == Decimal("500")

    with pytest.raises(NutritionDomainError):
        portion_to_grams(
            value=3500,
            unit="ml",
            canonical_food_id="food.ayran",
            conversions=table,
        )


def test_count_units_keep_their_own_ceiling():
    table = _table(
        UnitConversion(
            canonical_food_id="food.simit",
            unit="adet",
            grams_per_unit=Decimal("100"),
            source_item_id="local_mock",
            source_name="Yerel doğrulanmış tablo",
        )
    )
    assert portion_to_grams(
        value=2, unit="adet", canonical_food_id="food.simit", conversions=table
    ) == Decimal("200")

    with pytest.raises(NutritionDomainError):
        portion_to_grams(
            value=21,
            unit="adet",
            canonical_food_id="food.simit",
            conversions=table,
        )


def test_volume_without_a_verified_density_is_refused():
    # Yoğunluk yoksa "1 ml = 1 gram" varsayılmaz; uydurma değer üretmektense
    # birim hiç sunulmaz.
    with pytest.raises(NutritionDomainError):
        portion_to_grams(
            value=200,
            unit="ml",
            canonical_food_id="food.ayran",
            conversions={},
        )


def test_absurd_density_is_rejected_at_the_source():
    with pytest.raises(NutritionDomainError):
        _conversion("ml", "40")


def test_unknown_unit_is_refused():
    with pytest.raises(NutritionDomainError):
        portion_to_grams(
            value=1,
            unit="kova",
            canonical_food_id="food.ayran",
            conversions={},
        )


# ── Sağlayıcı yolu: hacim ölçüsünden yoğunluk türetme ──────────────────────

from app.services.nutritionix_service import NutritionixService  # noqa: E402


def _conversions_for(serving_unit: str, serving_quantity, grams: str) -> dict:
    """Verilen sunum ölçüsü için üretilen birim dönüşümlerini döndürür."""
    result = NutritionixService._result_dict(
        canonical=type("C", (), {
            "canonical_food_id": "food.ayran",
            "canonical_name": "ayran",
            "food_name_tr": "Ayran",
        })(),
        profile=type("P", (), {
            "calories": Decimal("37"), "protein": Decimal("1.7"),
            "carbs": Decimal("4.3"), "fat": Decimal("1.5"),
            "fiber": Decimal("0"),
        })(),
        calculation=type("K", (), {
            "portion_grams": Decimal(grams), "calories": Decimal("0"),
            "protein": Decimal("0"), "carbs": Decimal("0"),
            "fat": Decimal("0"), "fiber": Decimal("0"),
            "macro_calories": Decimal("0"),
            "macro_calorie_delta": Decimal("0"),
            "macro_calorie_delta_percent": Decimal("0"),
        })(),
        default_portion=Decimal(grams),
        portion_method="source_default",
        source="nutritionix",
        source_item_id="nix-1",
        source_locale="en-US",
        retrieved_at="2026-01-01T00:00:00Z",
        serving_unit=serving_unit,
        serving_quantity=serving_quantity,
        license_name="Nutritionix API Terms of Service",
        attribution="Nutrition data provided by Nutritionix",
    )
    return {row["unit"]: row["grams_per_unit"] for row in result["portion_conversions"]}


def test_fluid_ounce_serving_yields_a_real_density():
    # 8 fl oz = 246 g ise yogunluk 1.04 g/ml; sabit 1.0 varsaymak sutte ve
    # ayranda yuzde dort sapardi.
    rows = _conversions_for("fl_oz", 8, "246")
    assert round(rows["ml"], 3) == 1.04
    assert round(rows["litre"], 0) == 1040


def test_millilitre_serving_is_taken_as_is():
    rows = _conversions_for("ml", 250, "257.5")
    assert round(rows["ml"], 2) == 1.03


def test_piece_serving_still_yields_a_count_unit_and_no_volume():
    rows = _conversions_for("medium", 1, "100")
    assert rows["adet"] == 100
    assert "ml" not in rows


def test_response_schema_accepts_volume_portion_options():
    """A drink's ml/litre options must survive response validation.

    The response schema kept its own unit list and still rejected 'ml', so the
    search endpoint answered 500 for every beverage while the domain tests
    stayed green.
    """
    from app.models.schemas import PortionOption

    for unit, grams in (("ml", 1.03), ("litre", 1030.0), ("adet", 50.0)):
        option = PortionOption(
            unit=unit,
            grams_per_unit=grams,
            source_item_id="usda-fdc:2705385",
            source_name="USDA FoodData Central",
        )
        assert option.unit == unit


def test_manual_log_converts_volume_instead_of_storing_it_as_grams(
    client, monkeypatch
):
    """250 ml of milk is 257.5 g, not 250 g.

    The manual endpoint passed portion_value straight through as grams. While
    the schema pinned the unit to "gram" that was correct; once millilitres
    were allowed it silently mislabelled every drink.
    """
    from types import SimpleNamespace
    import uuid as uuid_module

    from app.main import app
    from app.models.database import SessionLocal, User, FoodLog
    from app.routers import food_router
    from app.routers.food_router import get_current_user

    from test_api_contract import traceable_nutrition

    class MilkNutrition:
        async def get_nutrition(self, *_args, **kwargs):
            payload = traceable_nutrition(
                calories_per_100g=61, portion_grams=100,
                protein=3.2, carb=4.8, fat=3.3, fiber=0.1,
                food_name="milk", food_name_tr="Süt (tam yağlı)",
            )
            payload["portion_conversions"] = [{
                "unit": "ml",
                "grams_per_unit": 1.03,
                "source_item_id": "usda-fdc:2705385",
                "source_name": "USDA FoodData Central",
            }]
            return payload

    user_id = str(uuid_module.uuid4())
    db = SessionLocal()
    db.add(User(
        id=user_id, email=f"{user_id}@example.com",
        hashed_password="unused", full_name="Volume User",
    ))
    db.commit()
    db.close()
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=user_id)
    monkeypatch.setattr(food_router, "nutrition_service", MilkNutrition())
    try:
        response = client.post("/api/v1/food-log/manual", json={
            "capture_id": str(uuid_module.uuid4()),
            "food_name": "milk",
            "food_name_tr": "Süt",
            "meal_type": "atistirmalik",
            "confirmed": True,
            "portion_value": 250,
            "portion_unit": "ml",
        })
        assert response.status_code == 200, response.text
        db = SessionLocal()
        try:
            log = db.query(FoodLog).filter(FoodLog.user_id == user_id).one()
            assert log.portion_unit == "ml"
            assert float(log.portion_value) == 250
            assert float(log.estimated_portion_g) == pytest.approx(257.5)
            assert float(log.total_calories) == pytest.approx(157.075, rel=1e-3)
        finally:
            db.close()
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_editing_a_millilitre_log_keeps_its_unit(client, monkeypatch):
    """Editing 250 ml to 300 ml must stay millilitres, not become 300 grams.

    The edit dialog pre-filled the entry's value but labelled it grams and
    sent it as grams, so a drink silently lost both its unit and its amount.
    """
    from types import SimpleNamespace
    import uuid as uuid_module

    from app.main import app
    from app.models.database import SessionLocal, User, FoodLog
    from app.routers import food_router
    from app.routers.food_router import get_current_user

    from test_api_contract import traceable_nutrition

    class MilkNutrition:
        async def get_nutrition(self, *_args, **_kwargs):
            payload = traceable_nutrition(
                calories_per_100g=61, portion_grams=100,
                protein=3.2, carb=4.8, fat=3.3, fiber=0.1,
                food_name="milk", food_name_tr="Süt (tam yağlı)",
            )
            payload["portion_conversions"] = [{
                "unit": "ml", "grams_per_unit": 1.03,
                "source_item_id": "usda-fdc:2705385",
                "source_name": "USDA FoodData Central",
            }]
            return payload

    user_id = str(uuid_module.uuid4())
    db = SessionLocal()
    db.add(User(
        id=user_id, email=f"{user_id}@example.com",
        hashed_password="unused", full_name="Edit User",
    ))
    db.commit()
    db.close()
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=user_id)
    monkeypatch.setattr(food_router, "nutrition_service", MilkNutrition())
    try:
        created = client.post("/api/v1/food-log/manual", json={
            "capture_id": str(uuid_module.uuid4()),
            "food_name": "milk",
            "food_name_tr": "Süt",
            "meal_type": "atistirmalik",
            "confirmed": True,
            "portion_value": 250,
            "portion_unit": "ml",
        })
        assert created.status_code == 200, created.text
        log_id = created.json()["log_id"]

        updated = client.patch(f"/api/v1/food-logs/{log_id}", json={
            "portion_value": 300, "portion_unit": "ml",
        })
        assert updated.status_code == 200, updated.text

        db = SessionLocal()
        try:
            log = db.query(FoodLog).filter(FoodLog.id == log_id).one()
            assert log.portion_unit == "ml"
            assert float(log.portion_value) == 300
            assert float(log.estimated_portion_g) == pytest.approx(309.0)
        finally:
            db.close()

        # Birim değiştirmek için doğrulanmış bir oran yok; sessizce
        # dönüştürmek yerine reddedilir.
        refused = client.patch(f"/api/v1/food-logs/{log_id}", json={
            "portion_value": 2, "portion_unit": "adet",
        })
        assert refused.status_code == 422
    finally:
        app.dependency_overrides.pop(get_current_user, None)
