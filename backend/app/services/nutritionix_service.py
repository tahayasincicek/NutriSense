"""Nutritionix adapter with explicit provenance and fail-closed local fallback."""

from __future__ import annotations

import json
import logging
import os
from dataclasses import replace
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import Optional
from urllib.parse import urlsplit

import httpx
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

from ..config import get_settings
from ..operations.metrics import runtime_metrics
from ..domain.nutrition import (
    NORMALIZATION_VERSION,
    NutritionDomainError,
    NutrientsPer100g,
    calculate_nutrition,
    food_lookup_key,
    normalize_food_name,
    validate_portion_grams,
    UnitConversion,
    to_decimal,
)

logger = logging.getLogger(__name__)
settings = get_settings()


def _resolve_local_db_path() -> Path:
    """Use the source-verified catalog bundled with app code in every layout.

    An explicit override is supported, but it passes the same per-record
    validation. The old ai_model prototype is never an automatic fallback.
    """

    override = os.getenv("CALORIE_DB_PATH", "").strip()
    if override:
        return Path(override)

    here = Path(__file__).resolve()
    candidates = (here.parents[1] / "data" / "verified_nutrition.json",)
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


LOCAL_DB_PATH = _resolve_local_db_path()
NUTRITIONIX_LICENSE = "Nutritionix API Terms of Service"
NUTRITIONIX_ATTRIBUTION = "Nutrition data provided by Nutritionix"


class NutritionixService:
    """Fetch nutrition data while preserving source and portion semantics."""

    API_BASE = "https://trackapi.nutritionix.com/v2"

    def __init__(self):
        self.app_id = settings.nutritionix_app_id
        self.api_key = settings.nutritionix_api_key
        self._provider_mode = settings.nutrition_provider_mode
        self._available = (
            self._provider_mode in {"nutritionix", "hybrid"}
            and bool(self.app_id and self.api_key)
        )
        self._local_meta, self._local_db = self._load_local_db()
        self._local_verified = (
            self._provider_mode in {"verified_local", "hybrid"}
            and self._local_meta.get("evidence_status") == "VERIFIED"
            and bool(self._local_meta.get("source_inventory"))
        )
        if self._available:
            logger.info("Nutritionix API yapılandırıldı")
        else:
            logger.warning("Nutritionix yapılandırılmadı; yalnız doğrulanmış yerel veri kullanılabilir.")
        if self._local_db and not self._local_verified:
            logger.warning("Yerel besin verisi doğrulanmamış; kalori sonucu olarak kullanılmayacak.")

    def _load_local_db(self) -> tuple[dict, dict]:
        if not LOCAL_DB_PATH.exists():
            logger.error(
                "Yerel kalori veritabanı bulunamadı (%s); manuel besin arama "
                "her sorguda 'Besin bulunamadı' dönecek. CALORIE_DB_PATH ile "
                "yolu belirtin.",
                LOCAL_DB_PATH,
            )
            return {}, {}
        try:
            with LOCAL_DB_PATH.open("r", encoding="utf-8") as file:
                payload = json.load(file)
            if not isinstance(payload, dict) or not isinstance(payload.get("_meta"), dict):
                raise ValueError("Invalid catalog")
            return payload["_meta"], {
                key: value for key, value in payload.items() if key != "_meta"
            }
        except (OSError, ValueError):
            logger.error("Yerel besin kataloğu okunamadı; doğrulanmamış sonuç üretilmeyecek.")
            return {}, {}

    def _validated_local_record(self, key: str):
        """Reject incomplete records individually, even in a VERIFIED catalog."""
        try:
            data = self._local_db[key]
            if data["evidence_status"] != "VERIFIED":
                return None
            source_id = data["source_item_id"]
            source = self._local_meta["source_inventory"][source_id]
            for field in ("license", "attribution", "source_url", "source_item_name"):
                value = source[field]
                if not isinstance(value, str) or not value.strip():
                    return None
                if value.strip().lower() in {"local", "mock data", "unknown", "placeholder"}:
                    return None
            url = urlsplit(source["source_url"])
            if url.scheme != "https" or not url.hostname:
                return None
            if not isinstance(source_id, str) or not source_id.strip():
                return None
            retrieved = datetime.fromisoformat(source["retrieved_at"].replace("Z", "+00:00"))
            if retrieved.tzinfo is None or retrieved > datetime.now(timezone.utc):
                return None
            profile = NutrientsPer100g(**{
                field: data[db_field] for field, db_field in (
                    ("calories", "calories_per_100g"), ("protein", "protein_per_100g"),
                    ("carbs", "carbs_per_100g"), ("fat", "fat_per_100g"),
                    ("fiber", "fiber_per_100g"),
                )
            })
            validate_portion_grams(data["default_portion_g"])
            for row in data.get("portion_units", []):
                # Units need their own evidence; a food citation alone is not a weight measurement.
                if row["source_item_id"] != source_id or not row["source_measure"]:
                    return None
                UnitConversion(
                    canonical_food_id=normalize_food_name(key, data.get("locale", "tr-TR")).canonical_food_id,
                    unit=row["unit"], grams_per_unit=row["grams_per_unit"],
                    source_item_id=source_id, source_name=source["attribution"],
                )
            return data, source, profile
        except (KeyError, TypeError, ValueError, AttributeError):
            return None

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(httpx.HTTPError),
        reraise=True,
    )
    async def get_nutrition(
        self,
        food_name: str,
        portion_grams: Optional[float] = None,
        *,
        input_locale: str = "en-US",
    ) -> dict:
        if portion_grams is not None:
            validate_portion_grams(portion_grams)
        if self._available:
            try:
                result = await self._query_api(food_name)
                if result:
                    runtime_metrics.provider_outcome("nutritionix", "success")
                    return self._format_result(
                        result, portion_grams, input_locale=input_locale
                    )
            except (httpx.HTTPError, NutritionDomainError, KeyError, TypeError) as exc:
                runtime_metrics.provider_outcome(
                    "nutritionix", "temporary_failure"
                )
                logger.warning("Nutritionix sonucu kullanılamadı: %s", type(exc).__name__)
        return self._query_local_db(food_name, portion_grams, input_locale=input_locale)

    async def _query_api(self, food_name: str) -> Optional[dict]:
        headers = {
            "x-app-id": self.app_id,
            "x-app-key": self.api_key,
            "Content-Type": "application/json",
        }
        body = {"query": food_name, "locale": "tr_TR"}
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{self.API_BASE}/natural/nutrients", headers=headers, json=body
            )
        if response.status_code == 200:
            foods = response.json().get("foods", [])
            return foods[0] if foods else None
        if response.status_code == 401:
            runtime_metrics.provider_outcome("nutritionix", "auth_error")
            logger.error("Nutritionix yetkilendirmesi başarısız")
            self._available = False
        elif response.status_code == 429:
            runtime_metrics.provider_outcome("nutritionix", "rate_limited")
            raise httpx.HTTPError("Nutritionix rate limit")
        return None

    def _format_result(
        self,
        api_food: dict,
        portion_grams: Optional[float],
        *,
        input_locale: str,
    ) -> dict:
        serving_weight = validate_portion_grams(api_food["serving_weight_grams"])
        if not isinstance(api_food.get("food_name"), str) or not api_food["food_name"].strip():
            raise NutritionDomainError("Sağlayıcının besin adı eksik.")
        canonical = normalize_food_name(api_food.get("food_name", ""), "en-US")
        profile = self._profile_from_serving(api_food, serving_weight)
        selected_grams = serving_weight if portion_grams is None else validate_portion_grams(portion_grams)
        calculation = calculate_nutrition(profile, selected_grams)
        source_item_id = str(
            api_food.get("nix_item_id")
            or f"common:{canonical.canonical_name}:{api_food.get('serving_qty', 1)}:{api_food.get('serving_unit', 'serving')}"
        )
        retrieved_at = datetime.now(timezone.utc).isoformat()
        return self._result_dict(
            canonical=canonical,
            profile=profile,
            calculation=calculation,
            default_portion=serving_weight,
            portion_method="source_default" if portion_grams is None else "user_selected",
            source="nutritionix",
            source_item_id=source_item_id,
            source_locale=input_locale,
            retrieved_at=retrieved_at,
            serving_unit=str(api_food.get("serving_unit") or "serving"),
            serving_quantity=api_food.get("serving_qty", 1),
            license_name=NUTRITIONIX_LICENSE,
            attribution=NUTRITIONIX_ATTRIBUTION,
        )

    @staticmethod
    def _profile_from_serving(api_food: dict, serving_weight: Decimal) -> NutrientsPer100g:
        scale = Decimal("100") / serving_weight
        return NutrientsPer100g(
            calories=to_decimal(api_food["nf_calories"], "calories") * scale,
            protein=to_decimal(api_food["nf_protein"], "protein") * scale,
            carbs=to_decimal(api_food["nf_total_carbohydrate"], "carbs") * scale,
            fat=to_decimal(api_food["nf_total_fat"], "fat") * scale,
            fiber=to_decimal(api_food["nf_dietary_fiber"], "fiber") * scale,
        )

    def _query_local_db(
        self,
        food_name: str,
        portion_grams: Optional[float],
        *,
        input_locale: str = "tr-TR",
    ) -> dict:
        # "Köfte", "kofte", "KÖFTE" hepsi `kofte` anahtarına inmeli; düz
        # lower()+replace() Türkçe karakterleri koruyup eşleşmeyi kaçırıyordu.
        key = food_lookup_key(food_name)
        if key not in self._local_db:
            for candidate_key, candidate in self._local_db.items():
                if isinstance(candidate, dict) and key == food_lookup_key(candidate.get("display_name_tr", "")):
                    key = candidate_key
                    break
            else:
                key = normalize_food_name(food_name, input_locale).canonical_name
        validated = self._validated_local_record(key) if self._local_verified else None
        if validated is None:
            runtime_metrics.provider_outcome("verified_local", "not_found")
            logger.warning("Doğrulanmış besin değeri bulunamadı")
            return self._not_found(food_name, input_locale)

        data, source_info, profile = validated
        canonical = normalize_food_name(key, input_locale)
        canonical = replace(canonical, food_name_tr=data.get("display_name_tr", canonical.food_name_tr))
        default_portion = validate_portion_grams(data["default_portion_g"])
        selected_grams = default_portion if portion_grams is None else validate_portion_grams(portion_grams)
        calculation = calculate_nutrition(profile, selected_grams)
        source_item_id = data["source_item_id"]
        runtime_metrics.provider_outcome("verified_local", "success")
        return self._result_dict(
            canonical=canonical,
            profile=profile,
            calculation=calculation,
            default_portion=default_portion,
            portion_method="source_default" if portion_grams is None else "user_selected",
            source="local_verified",
            source_item_id=source_item_id,
            source_locale=data.get("locale", "tr-TR"),
            retrieved_at=source_info["retrieved_at"],
            serving_unit=data.get("serving_unit", "gram"),
            serving_quantity=data.get("serving_quantity", 1),
            license_name=source_info["license"],
            attribution=source_info["attribution"],
            # Yerel veritabanı besin başına birim karşılığı taşıyabilir:
            # bir simit kaç gram, bir mililitre ayran kaç gram. Sağlayıcı
            # ölçüsü yokken kullanıcı yine de "1 adet" ya da "200 ml"
            # diyebilsin.
            declared_units=data.get("portion_units"),
        )

    @staticmethod
    def _result_dict(
        *, canonical, profile, calculation, default_portion, portion_method,
        source, source_item_id, source_locale, retrieved_at, serving_unit,
        serving_quantity, license_name, attribution, declared_units=None,
    ) -> dict:
        unit_aliases = {
            "medium": "adet", "small": "adet", "large": "adet",
            "item": "adet", "piece": "adet", "slice": "dilim", "bowl": "kase",
        }
        # Sağlayıcı hacim ölçüsü verdiğinde porsiyon ağırlığından besinin
        # gerçek yoğunluğu çıkar: 8 fl oz = 240 g ise 1 ml = 1.014 g. Sabit
        # "1 ml = 1 gram" varsaymak sütte ve meyve suyunda yüzde üç ile beş
        # arası sapma bırakırdı.
        volume_ml = {
            "ml": Decimal("1"), "milliliter": Decimal("1"),
            "millilitre": Decimal("1"),
            "fl_oz": Decimal("29.5735"), "fl oz": Decimal("29.5735"),
            "cup": Decimal("236.588"), "tbsp": Decimal("14.7868"),
            "tsp": Decimal("4.92892"),
            "l": Decimal("1000"), "liter": Decimal("1000"),
            "litre": Decimal("1000"),
        }
        normalized_unit = str(serving_unit).lower().strip()
        converted_unit = unit_aliases.get(normalized_unit)
        conversions = []
        quantity = Decimal(str(serving_quantity or 1))
        if converted_unit and quantity > 0:
            conversions.append({
                "unit": converted_unit,
                "grams_per_unit": float(Decimal(str(default_portion)) / quantity),
                "source_item_id": source_item_id,
                "source_name": attribution,
            })
        millilitres = volume_ml.get(normalized_unit)
        if millilitres is not None and quantity > 0:
            density = Decimal(str(default_portion)) / (quantity * millilitres)
            if Decimal("0") < density <= Decimal("2"):
                conversions.append({
                    "unit": "ml",
                    "grams_per_unit": float(density),
                    "source_item_id": source_item_id,
                    "source_name": attribution,
                })
                conversions.append({
                    "unit": "litre",
                    "grams_per_unit": float(density * Decimal("1000")),
                    "source_item_id": source_item_id,
                    "source_name": attribution,
                })
        # Veritabanında elle tanımlanmış birimler. Sağlayıcıdan gelen ölçü
        # önceliklidir; aynı birim iki kez tanımlanmaz.
        seen = {row["unit"] for row in conversions}
        for row in declared_units or []:
            unit = str(row.get("unit", "")).strip()
            # Doğrulayıcı litre satırını da kabul ediyor; burada elenirse
            # kayıt geçerli sayılıp birim sessizce kaybolurdu.
            if unit in seen or unit not in {"adet", "dilim", "kase", "ml", "litre"}:
                continue
            grams = Decimal(str(row["grams_per_unit"]))
            if grams <= 0:
                continue
            conversions.append({
                "unit": unit,
                "grams_per_unit": float(grams),
                "source_item_id": source_item_id,
                "source_name": attribution,
            })
            seen.add(unit)
            if unit == "ml" and "litre" not in seen:
                conversions.append({
                    "unit": "litre",
                    "grams_per_unit": float(grams * Decimal("1000")),
                    "source_item_id": source_item_id,
                    "source_name": attribution,
                })
                seen.add("litre")
        return {
            "available": True,
            "canonical_food_id": canonical.canonical_food_id,
            "food_name": canonical.canonical_name,
            "food_name_tr": canonical.food_name_tr,
            "normalization_version": NORMALIZATION_VERSION,
            "calories_per_100g": float(profile.calories),
            "default_portion_g": float(default_portion),
            "estimated_portion_g": float(calculation.portion_grams),
            "portion_value": float(calculation.portion_grams),
            "portion_unit": "gram",
            "portion_method": portion_method,
            "portion_is_estimate": portion_method == "source_default",
            "total_calories": float(calculation.calories),
            "nutrients": {
                "protein": float(calculation.protein),
                "carb": float(calculation.carbs),
                "fat": float(calculation.fat),
                "fiber": float(calculation.fiber),
            },
            "nutrients_per_100g": {
                "protein": float(profile.protein),
                "carb": float(profile.carbs),
                "fat": float(profile.fat),
                "fiber": float(profile.fiber),
            },
            "macro_calories": float(calculation.macro_calories),
            "macro_calorie_delta": float(calculation.macro_calorie_delta),
            "macro_calorie_delta_percent": float(calculation.macro_calorie_delta_percent),
            "source": source,
            "nutrition_reliability": "verified_provider" if source == "nutritionix" else "verified_local",
            "provenance": {
                "source": source,
                "source_item_id": source_item_id,
                "locale": source_locale,
                "retrieved_at": retrieved_at,
                "serving_unit": serving_unit,
                "serving_grams": float(default_portion),
                "license_name": license_name,
                "attribution": attribution,
            },
            "portion_conversions": conversions,
        }

    @staticmethod
    def _not_found(food_name: str, input_locale: str) -> dict:
        canonical = normalize_food_name(food_name, input_locale)
        return {
            "available": False,
            "canonical_food_id": canonical.canonical_food_id,
            "food_name": canonical.canonical_name,
            "food_name_tr": canonical.food_name_tr,
            "normalization_version": NORMALIZATION_VERSION,
            "source": "not_found",
            "nutrition_reliability": "not_found",
            "provenance": None,
        }

    async def search_foods(self, query: str, limit: int = 10) -> list[dict]:
        if self._available:
            try:
                headers = {"x-app-id": self.app_id, "x-app-key": self.api_key}
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(
                        f"{self.API_BASE}/search/instant",
                        headers=headers,
                        params={"query": query},
                    )
                if response.status_code == 200:
                    return [
                        {"food_name": item.get("food_name", ""), "photo": item.get("photo", {}).get("thumb", "")}
                        for item in response.json().get("common", [])[:limit]
                    ]
            except httpx.HTTPError:
                logger.warning("Nutritionix araması kullanılamıyor")
        if not self._local_verified:
            return []
        query_lower = food_lookup_key(query)
        return [
            {"food_name": key, "photo": ""}
            for key, data in self._local_db.items()
            if self._validated_local_record(key) is not None
            and (query_lower in key or query_lower in food_lookup_key(data.get("display_name_tr", "")))
        ][:limit]
