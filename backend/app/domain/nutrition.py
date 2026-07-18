"""Traceable nutrition calculations without presentation-layer rounding.

This module deliberately has no HTTP, database or provider dependencies.  A
provider response is accepted only after its provenance and portion have been
made explicit, so the same calculation can be reused by scan results, stored
food logs and dietitian reports.
"""

from __future__ import annotations

import math
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, InvalidOperation
from enum import StrEnum
from typing import Mapping


NORMALIZATION_VERSION = "tr-en-canonical-v1"
MAX_PORTION_GRAMS = Decimal("2000")


class NutritionDomainError(ValueError):
    """Raised when unsafe or incomplete nutrition input is supplied."""


class NutritionSourceKind(StrEnum):
    NUTRITIONIX = "nutritionix"
    LOCAL_VERIFIED = "local_verified"
    USER_ENTERED = "user_entered"
    OTHER_VERIFIED = "other_verified"


class PortionMethod(StrEnum):
    SOURCE_DEFAULT = "source_default"
    USER_SELECTED = "user_selected"
    USER_VOICE = "user_voice"


@dataclass(frozen=True)
class CanonicalFood:
    canonical_food_id: str
    canonical_name: str
    food_name_tr: str
    input_locale: str
    mapping_version: str = NORMALIZATION_VERSION
    mapped: bool = True


@dataclass(frozen=True)
class NutritionProvenance:
    source: NutritionSourceKind
    source_item_id: str
    locale: str
    retrieved_at: datetime
    serving_unit: str
    serving_grams: Decimal
    license_name: str
    attribution: str

    def __post_init__(self) -> None:
        if not self.source_item_id.strip():
            raise NutritionDomainError("Kaynak kayıt kimliği zorunludur.")
        if not self.locale.strip():
            raise NutritionDomainError("Kaynak dili zorunludur.")
        if self.retrieved_at.tzinfo is None:
            raise NutritionDomainError("Kaynak erişim zamanı timezone-aware olmalıdır.")
        if not self.serving_unit.strip():
            raise NutritionDomainError("Kaynak porsiyon birimi zorunludur.")
        validate_portion_grams(self.serving_grams)
        if not self.license_name.strip() or not self.attribution.strip():
            raise NutritionDomainError("Lisans ve atıf bilgisi zorunludur.")


@dataclass(frozen=True)
class NutrientsPer100g:
    calories: Decimal
    protein: Decimal
    carbs: Decimal
    fat: Decimal
    fiber: Decimal = Decimal("0")

    def __post_init__(self) -> None:
        for field_name in ("calories", "protein", "carbs", "fat", "fiber"):
            value = to_decimal(getattr(self, field_name), field_name)
            if value < 0:
                raise NutritionDomainError(f"{field_name} negatif olamaz.")
            object.__setattr__(self, field_name, value)
        if self.calories == 0:
            raise NutritionDomainError(
                "Sıfır kalorili değer, doğrulanmış besin sonucu olarak kullanılamaz."
            )


@dataclass(frozen=True)
class NutritionCalculation:
    portion_grams: Decimal
    calories: Decimal
    protein: Decimal
    carbs: Decimal
    fat: Decimal
    fiber: Decimal
    macro_calories: Decimal
    macro_calorie_delta: Decimal
    macro_calorie_delta_percent: Decimal


def to_decimal(value: object, field_name: str) -> Decimal:
    """Convert API/user numeric input without importing binary float error."""

    if isinstance(value, bool):
        raise NutritionDomainError(f"{field_name} sayısal olmalıdır.")
    if isinstance(value, float) and not math.isfinite(value):
        raise NutritionDomainError(f"{field_name} sonlu olmalıdır.")
    try:
        result = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError) as exc:
        raise NutritionDomainError(f"{field_name} geçerli bir sayı olmalıdır.") from exc
    if not result.is_finite():
        raise NutritionDomainError(f"{field_name} sonlu olmalıdır.")
    return result


def validate_portion_grams(value: object) -> Decimal:
    grams = to_decimal(value, "portion_grams")
    if grams <= 0:
        raise NutritionDomainError("Porsiyon sıfırdan büyük olmalıdır.")
    if grams > MAX_PORTION_GRAMS:
        raise NutritionDomainError(
            f"Porsiyon {MAX_PORTION_GRAMS} gramdan büyük olamaz."
        )
    return grams


def calculate_nutrition(
    nutrients_per_100g: NutrientsPer100g,
    portion_grams: object,
) -> NutritionCalculation:
    """Scale calories and macros once; callers round only while presenting."""

    grams = validate_portion_grams(portion_grams)
    factor = grams / Decimal("100")
    calories = nutrients_per_100g.calories * factor
    protein = nutrients_per_100g.protein * factor
    carbs = nutrients_per_100g.carbs * factor
    fat = nutrients_per_100g.fat * factor
    fiber = nutrients_per_100g.fiber * factor
    macro_calories = protein * Decimal("4") + carbs * Decimal("4") + fat * Decimal("9")
    delta = macro_calories - calories
    delta_percent = abs(delta) / calories * Decimal("100")
    return NutritionCalculation(
        portion_grams=grams,
        calories=calories,
        protein=protein,
        carbs=carbs,
        fat=fat,
        fiber=fiber,
        macro_calories=macro_calories,
        macro_calorie_delta=delta,
        macro_calorie_delta_percent=delta_percent,
    )


_ALIASES: Mapping[tuple[str, str], tuple[str, str, str]] = {
    ("pasta", "en"): ("food.pasta", "pasta", "Makarna"),
    ("pasta", "tr"): ("food.cake", "cake", "Pasta"),
    ("makarna", "tr"): ("food.pasta", "pasta", "Makarna"),
    ("cake", "en"): ("food.cake", "cake", "Pasta"),
    ("apple", "en"): ("food.apple", "apple", "Elma"),
    ("elma", "tr"): ("food.apple", "apple", "Elma"),
    ("banana", "en"): ("food.banana", "banana", "Muz"),
    ("muz", "tr"): ("food.banana", "banana", "Muz"),
    ("rice", "en"): ("food.rice", "rice", "Pilav"),
    ("pilav", "tr"): ("food.rice", "rice", "Pilav"),
    ("bread", "en"): ("food.bread", "bread", "Ekmek"),
    ("ekmek", "tr"): ("food.bread", "bread", "Ekmek"),
    ("egg", "en"): ("food.egg", "egg", "Yumurta"),
    ("yumurta", "tr"): ("food.egg", "egg", "Yumurta"),
}


def _slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.strip().lower())
    ascii_text = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")


def normalize_food_name(food_name: str, locale: str) -> CanonicalFood:
    """Resolve names with locale so English pasta never becomes Turkish cake."""

    if not food_name.strip():
        raise NutritionDomainError("Besin adı boş olamaz.")
    language = locale.replace("_", "-").split("-", 1)[0].lower()
    if language not in {"tr", "en"}:
        raise NutritionDomainError("Besin normalizasyonu için tr veya en locale gerekir.")
    key = _slug(food_name)
    resolved = _ALIASES.get((key, language))
    if resolved:
        food_id, canonical_name, food_name_tr = resolved
        return CanonicalFood(food_id, canonical_name, food_name_tr, locale)
    display_name = food_name.strip().title()
    return CanonicalFood(
        canonical_food_id=f"food.unmapped.{language}.{key}",
        canonical_name=key,
        food_name_tr=display_name,
        input_locale=locale,
        mapped=False,
    )


@dataclass(frozen=True)
class UnitConversion:
    canonical_food_id: str
    unit: str
    grams_per_unit: Decimal
    source_item_id: str
    source_name: str

    def __post_init__(self) -> None:
        object.__setattr__(
            self, "grams_per_unit", validate_portion_grams(self.grams_per_unit)
        )
        if self.unit not in {"adet", "dilim", "kase"}:
            raise NutritionDomainError("Desteklenmeyen porsiyon birimi.")
        if not self.source_item_id.strip() or not self.source_name.strip():
            raise NutritionDomainError("Birim dönüşüm kaynağı zorunludur.")


def portion_to_grams(
    *,
    value: object,
    unit: str,
    canonical_food_id: str,
    conversions: Mapping[tuple[str, str], UnitConversion],
) -> Decimal:
    amount = to_decimal(value, "portion_value")
    if amount <= 0 or amount > Decimal("20"):
        raise NutritionDomainError("Birim adedi 0 ile 20 arasında olmalıdır.")
    if unit == "gram":
        return validate_portion_grams(amount)
    conversion = conversions.get((canonical_food_id, unit))
    if conversion is None:
        raise NutritionDomainError(
            "Bu besin ve birim için doğrulanmış gram dönüşümü bulunmuyor."
        )
    return validate_portion_grams(amount * conversion.grams_per_unit)
