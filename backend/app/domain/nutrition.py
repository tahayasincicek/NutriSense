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
    ("baklava", "en"): ("food.baklava", "baklava", "Baklava"),
    ("baklava", "tr"): ("food.baklava", "baklava", "Baklava"),
    ("hamburger", "en"): ("food.hamburger", "hamburger", "Hamburger"),
    ("hamburger", "tr"): ("food.hamburger", "hamburger", "Hamburger"),
    ("pizza", "en"): ("food.pizza", "pizza", "Pizza"),
    ("pizza", "tr"): ("food.pizza", "pizza", "Pizza"),
    ("omelette", "en"): ("food.omelette", "omelette", "Omlet"),
    ("omelet", "en"): ("food.omelette", "omelette", "Omlet"),
    ("omlet", "tr"): ("food.omelette", "omelette", "Omlet"),
    ("french_fries", "en"): (
        "food.french_fries", "french_fries", "Patates kızartması"
    ),
    ("patates_kizartmasi", "tr"): (
        "food.french_fries", "french_fries", "Patates kızartması"
    ),
    ("simit", "en"): ("food.simit", "simit", "Simit"),
    ("simit", "tr"): ("food.simit", "simit", "Simit"),
    ("lahmacun", "en"): ("food.lahmacun", "lahmacun", "Lahmacun"),
    ("lahmacun", "tr"): ("food.lahmacun", "lahmacun", "Lahmacun"),
    ("manti", "en"): ("food.manti", "manti", "Mantı"),
    ("manti", "tr"): ("food.manti", "manti", "Mantı"),
    ("lentil_soup", "en"): (
        "food.mercimek_corbasi", "lentil_soup", "Mercimek çorbası"
    ),
    ("mercimek_corbasi", "tr"): (
        "food.mercimek_corbasi", "lentil_soup", "Mercimek çorbası"
    ),
    ("menemen", "en"): ("food.menemen", "menemen", "Menemen"),
    ("menemen", "tr"): ("food.menemen", "menemen", "Menemen"),
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
    # Doğrulanmış katalogdaki besinler Türkçe adlarıyla da bulunabilmeli.
    # Kanonik ad katalog anahtarıyla birebir aynı olmalı; yoksa arama
    # kaydı bulamaz ve "besin bulunamadı" döner.
    ("milk", "en"): ("food.milk", "milk", "Süt"),
    ("sut", "tr"): ("food.milk", "milk", "Süt"),
    ("tea", "en"): ("food.tea", "tea", "Çay"),
    ("cay", "tr"): ("food.tea", "tea", "Çay"),
    ("turkish_coffee", "en"): (
        "food.turkish_coffee", "turkish_coffee", "Türk kahvesi"
    ),
    ("turk_kahvesi", "tr"): (
        "food.turkish_coffee", "turkish_coffee", "Türk kahvesi"
    ),
    ("kahve", "tr"): ("food.turkish_coffee", "turkish_coffee", "Türk kahvesi"),
    ("orange_juice", "en"): (
        "food.orange_juice", "orange_juice", "Portakal suyu"
    ),
    ("portakal_suyu", "tr"): (
        "food.orange_juice", "orange_juice", "Portakal suyu"
    ),
    ("cola", "en"): ("food.cola", "cola", "Kola"),
    ("kola", "tr"): ("food.cola", "cola", "Kola"),
    ("yogurt", "en"): ("food.yogurt", "yogurt", "Yoğurt"),
    ("yogurt", "tr"): ("food.yogurt", "yogurt", "Yoğurt"),
    ("feta_cheese", "en"): ("food.feta_cheese", "feta_cheese", "Beyaz peynir"),
    ("beyaz_peynir", "tr"): (
        "food.feta_cheese", "feta_cheese", "Beyaz peynir"
    ),
    ("peynir", "tr"): ("food.feta_cheese", "feta_cheese", "Beyaz peynir"),
    ("green_olives", "en"): (
        "food.green_olives", "green_olives", "Yeşil zeytin"
    ),
    ("zeytin", "tr"): ("food.green_olives", "green_olives", "Yeşil zeytin"),
    ("walnuts", "en"): ("food.walnuts", "walnuts", "Ceviz"),
    ("ceviz", "tr"): ("food.walnuts", "walnuts", "Ceviz"),
    ("bulgur", "en"): ("food.bulgur", "bulgur", "Bulgur"),
    ("bulgur", "tr"): ("food.bulgur", "bulgur", "Bulgur"),
    ("boiled_potato", "en"): (
        "food.boiled_potato", "boiled_potato", "Haşlanmış patates"
    ),
    ("haslanmis_patates", "tr"): (
        "food.boiled_potato", "boiled_potato", "Haşlanmış patates"
    ),
    ("patates", "tr"): (
        "food.boiled_potato", "boiled_potato", "Haşlanmış patates"
    ),
    ("chicken_breast", "en"): (
        "food.chicken_breast", "chicken_breast", "Tavuk göğsü"
    ),
    ("tavuk_gogsu", "tr"): (
        "food.chicken_breast", "chicken_breast", "Tavuk göğsü"
    ),
    ("tavuk", "tr"): ("food.chicken_breast", "chicken_breast", "Tavuk göğsü"),
    ("lamb", "en"): ("food.lamb", "lamb", "Kuzu eti"),
    ("kuzu_eti", "tr"): ("food.lamb", "lamb", "Kuzu eti"),
    ("kuzu", "tr"): ("food.lamb", "lamb", "Kuzu eti"),
    ("hummus", "en"): ("food.hummus", "hummus", "Humus"),
    ("humus", "tr"): ("food.hummus", "hummus", "Humus"),
    ("chickpeas", "en"): ("food.chickpeas", "chickpeas", "Nohut"),
    ("nohut", "tr"): ("food.chickpeas", "chickpeas", "Nohut"),
    ("vegetable_soup", "en"): (
        "food.vegetable_soup", "vegetable_soup", "Sebze çorbası"
    ),
    ("sebze_corbasi", "tr"): (
        "food.vegetable_soup", "vegetable_soup", "Sebze çorbası"
    ),
    ("orange", "en"): ("food.orange", "orange", "Portakal"),
    ("portakal", "tr"): ("food.orange", "orange", "Portakal"),
    ("watermelon", "en"): ("food.watermelon", "watermelon", "Karpuz"),
    ("karpuz", "tr"): ("food.watermelon", "watermelon", "Karpuz"),
    ("tomato", "en"): ("food.tomato", "tomato", "Domates"),
    ("domates", "tr"): ("food.tomato", "tomato", "Domates"),
    ("cucumber", "en"): ("food.cucumber", "cucumber", "Salatalık"),
    ("salatalik", "tr"): ("food.cucumber", "cucumber", "Salatalık"),
    ("milk_reduced_fat", "en"): ("food.milk_reduced_fat", "milk_reduced_fat", "Süt (yarım yağlı)"),
    ("yarim_yagli_sut", "tr"): ("food.milk_reduced_fat", "milk_reduced_fat", "Süt (yarım yağlı)"),
    ("ice_cream", "en"): ("food.ice_cream", "ice_cream", "Dondurma"),
    ("dondurma", "tr"): ("food.ice_cream", "ice_cream", "Dondurma"),
    ("cheddar_cheese", "en"): ("food.cheddar_cheese", "cheddar_cheese", "Kaşar benzeri peynir"),
    ("kasar", "tr"): ("food.cheddar_cheese", "cheddar_cheese", "Kaşar benzeri peynir"),
    ("kasar_peyniri", "tr"): ("food.cheddar_cheese", "cheddar_cheese", "Kaşar benzeri peynir"),
    ("cheddar", "tr"): ("food.cheddar_cheese", "cheddar_cheese", "Kaşar benzeri peynir"),
    ("cottage_cheese", "en"): ("food.cottage_cheese", "cottage_cheese", "Lor peyniri"),
    ("lor", "tr"): ("food.cottage_cheese", "cottage_cheese", "Lor peyniri"),
    ("lor_peyniri", "tr"): ("food.cottage_cheese", "cottage_cheese", "Lor peyniri"),
    ("ground_beef", "en"): ("food.ground_beef", "ground_beef", "Dana kıyma"),
    ("kiyma", "tr"): ("food.ground_beef", "ground_beef", "Dana kıyma"),
    ("dana_kiyma", "tr"): ("food.ground_beef", "ground_beef", "Dana kıyma"),
    ("chicken_thigh", "en"): ("food.chicken_thigh", "chicken_thigh", "Tavuk but"),
    ("tavuk_but", "tr"): ("food.chicken_thigh", "chicken_thigh", "Tavuk but"),
    ("but", "tr"): ("food.chicken_thigh", "chicken_thigh", "Tavuk but"),
    ("fish", "en"): ("food.fish", "fish", "Balık"),
    ("balik", "tr"): ("food.fish", "fish", "Balık"),
    ("shrimp", "en"): ("food.shrimp", "shrimp", "Karides"),
    ("karides", "tr"): ("food.shrimp", "shrimp", "Karides"),
    ("meatballs", "en"): ("food.meatballs", "meatballs", "Köfte"),
    ("kofte", "tr"): ("food.meatballs", "meatballs", "Köfte"),
    ("white_beans", "en"): ("food.white_beans", "white_beans", "Beyaz fasulye"),
    ("beyaz_fasulye", "tr"): ("food.white_beans", "white_beans", "Beyaz fasulye"),
    ("lentils", "en"): ("food.lentils", "lentils", "Mercimek"),
    ("mercimek", "tr"): ("food.lentils", "lentils", "Mercimek"),
    ("almonds", "en"): ("food.almonds", "almonds", "Badem"),
    ("badem", "tr"): ("food.almonds", "almonds", "Badem"),
    ("hazelnuts", "en"): ("food.hazelnuts", "hazelnuts", "Fındık"),
    ("findik", "tr"): ("food.hazelnuts", "hazelnuts", "Fındık"),
    ("pistachios", "en"): ("food.pistachios", "pistachios", "Antep fıstığı"),
    ("antep_fistigi", "tr"): ("food.pistachios", "pistachios", "Antep fıstığı"),
    ("fistik", "tr"): ("food.pistachios", "pistachios", "Antep fıstığı"),
    ("bagel", "en"): ("food.bagel", "bagel", "Halka ekmek"),
    ("halka_ekmek", "tr"): ("food.bagel", "bagel", "Halka ekmek"),
    ("whole_wheat_bread", "en"): ("food.whole_wheat_bread", "whole_wheat_bread", "Tam buğday ekmeği"),
    ("tam_bugday_ekmegi", "tr"): ("food.whole_wheat_bread", "whole_wheat_bread", "Tam buğday ekmeği"),
    ("kepekli_ekmek", "tr"): ("food.whole_wheat_bread", "whole_wheat_bread", "Tam buğday ekmeği"),
    ("brown_rice", "en"): ("food.brown_rice", "brown_rice", "Esmer pirinç pilavı"),
    ("esmer_pirinc", "tr"): ("food.brown_rice", "brown_rice", "Esmer pirinç pilavı"),
    ("couscous", "en"): ("food.couscous", "couscous", "Kuskus"),
    ("kuskus", "tr"): ("food.couscous", "couscous", "Kuskus"),
    ("cheese_pastry", "en"): ("food.cheese_pastry", "cheese_pastry", "Peynirli börek benzeri hamur işi"),
    ("peynirli_borek", "tr"): ("food.cheese_pastry", "cheese_pastry", "Peynirli börek benzeri hamur işi"),
    ("borek", "tr"): ("food.cheese_pastry", "cheese_pastry", "Peynirli börek benzeri hamur işi"),
    ("chicken_noodle_soup", "en"): ("food.chicken_noodle_soup", "chicken_noodle_soup", "Tavuklu şehriye çorbası"),
    ("tavuk_corbasi", "tr"): ("food.chicken_noodle_soup", "chicken_noodle_soup", "Tavuklu şehriye çorbası"),
    ("sehriye_corbasi", "tr"): ("food.chicken_noodle_soup", "chicken_noodle_soup", "Tavuklu şehriye çorbası"),
    ("raisins", "en"): ("food.raisins", "raisins", "Kuru üzüm"),
    ("kuru_uzum", "tr"): ("food.raisins", "raisins", "Kuru üzüm"),
    ("apricot", "en"): ("food.apricot", "apricot", "Kayısı"),
    ("kayisi", "tr"): ("food.apricot", "apricot", "Kayısı"),
    ("cherry", "en"): ("food.cherry", "cherry", "Kiraz"),
    ("kiraz", "tr"): ("food.cherry", "cherry", "Kiraz"),
    ("fig", "en"): ("food.fig", "fig", "İncir"),
    ("incir", "tr"): ("food.fig", "fig", "İncir"),
    ("grapes", "en"): ("food.grapes", "grapes", "Üzüm"),
    ("uzum", "tr"): ("food.grapes", "grapes", "Üzüm"),
    ("strawberry", "en"): ("food.strawberry", "strawberry", "Çilek"),
    ("cilek", "tr"): ("food.strawberry", "strawberry", "Çilek"),
    ("apple_juice", "en"): ("food.apple_juice", "apple_juice", "Elma suyu"),
    ("elma_suyu", "tr"): ("food.apple_juice", "apple_juice", "Elma suyu"),
    ("carrot", "en"): ("food.carrot", "carrot", "Havuç"),
    ("havuc", "tr"): ("food.carrot", "carrot", "Havuç"),
    ("tomato_soup", "en"): ("food.tomato_soup", "tomato_soup", "Domates çorbası"),
    ("domates_corbasi", "tr"): ("food.tomato_soup", "tomato_soup", "Domates çorbası"),
    ("eggplant", "en"): ("food.eggplant", "eggplant", "Patlıcan"),
    ("patlican", "tr"): ("food.eggplant", "eggplant", "Patlıcan"),
    ("lettuce", "en"): ("food.lettuce", "lettuce", "Marul"),
    ("marul", "tr"): ("food.lettuce", "lettuce", "Marul"),
    ("onion", "en"): ("food.onion", "onion", "Soğan"),
    ("sogan", "tr"): ("food.onion", "onion", "Soğan"),
    ("green_pepper", "en"): ("food.green_pepper", "green_pepper", "Yeşil biber"),
    ("yesil_biber", "tr"): ("food.green_pepper", "green_pepper", "Yeşil biber"),
    ("biber", "tr"): ("food.green_pepper", "green_pepper", "Yeşil biber"),
    ("butter", "en"): ("food.butter", "butter", "Tereyağı"),
    ("tereyagi", "tr"): ("food.butter", "butter", "Tereyağı"),
    ("olive_oil", "en"): ("food.olive_oil", "olive_oil", "Zeytinyağı"),
    ("zeytinyagi", "tr"): ("food.olive_oil", "olive_oil", "Zeytinyağı"),
    ("honey", "en"): ("food.honey", "honey", "Bal"),
    ("bal", "tr"): ("food.honey", "honey", "Bal"),
    ("jam", "en"): ("food.jam", "jam", "Reçel"),
    ("recel", "tr"): ("food.jam", "jam", "Reçel"),
    ("brewed_coffee", "en"): ("food.brewed_coffee", "brewed_coffee", "Filtre kahve"),
    ("filtre_kahve", "tr"): ("food.brewed_coffee", "brewed_coffee", "Filtre kahve"),
    ("green_tea", "en"): ("food.green_tea", "green_tea", "Yeşil çay"),
    ("yesil_cay", "tr"): ("food.green_tea", "green_tea", "Yeşil çay"),
    ("lemonade", "en"): ("food.lemonade", "lemonade", "Limonata"),
    ("limonata", "tr"): ("food.lemonade", "lemonade", "Limonata"),
}


def _slug(value: str) -> str:
    # U+0131 LATIN SMALL LETTER DOTLESS I does not decompose under NFKD.
    # Transliterate it explicitly so Turkish names remain stable canonical keys.
    normalized = unicodedata.normalize(
        "NFKD", value.strip().lower().translate(str.maketrans({"ı": "i"}))
    )
    ascii_text = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")


def food_lookup_key(food_name: str) -> str:
    """Public slug used to look names up in the verified local calorie database.

    Shares `_slug` so "Köfte", "kofte" and "KÖFTE" all resolve to `kofte`.
    """

    return _slug(food_name)


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


COUNT_UNITS = frozenset({"adet", "dilim", "kase"})
VOLUME_UNITS = frozenset({"ml", "litre"})
PORTION_UNITS = frozenset({"gram"}) | COUNT_UNITS | VOLUME_UNITS

# Birim başına üst sınır. Sayılabilir birimlerde 20 adet makul bir tavan;
# hacimde aynı tavanı kullanmak 20 ml'de kesip su kaydını imkânsız kılardı.
_UNIT_LIMITS = {
    "adet": Decimal("20"),
    "dilim": Decimal("20"),
    "kase": Decimal("20"),
    "ml": Decimal("3000"),
    "litre": Decimal("3"),
}


@dataclass(frozen=True)
class UnitConversion:
    canonical_food_id: str
    unit: str
    grams_per_unit: Decimal
    source_item_id: str
    source_name: str

    def __post_init__(self) -> None:
        # Bir mililitre gram cinsinden 1 civarıdır; porsiyon doğrulaması alt
        # sınır olarak bir gram beklediği için hacim birimleri o denetimin
        # dışında tutulur, yalnız pozitiflik ve akla yatkınlık aranır.
        if self.unit in VOLUME_UNITS:
            density = to_decimal(self.grams_per_unit, "grams_per_unit")
            ceiling = Decimal("2000") if self.unit == "litre" else Decimal("2")
            if density <= 0 or density > ceiling:
                raise NutritionDomainError("Birim yoğunluğu akla yatkın değil.")
            object.__setattr__(self, "grams_per_unit", density)
        else:
            object.__setattr__(
                self, "grams_per_unit", validate_portion_grams(self.grams_per_unit)
            )
        if self.unit not in COUNT_UNITS | VOLUME_UNITS:
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
    if unit == "gram":
        return validate_portion_grams(amount)
    limit = _UNIT_LIMITS.get(unit)
    if limit is None:
        raise NutritionDomainError("Desteklenmeyen porsiyon birimi.")
    if amount <= 0 or amount > limit:
        raise NutritionDomainError(
            f"Porsiyon miktarı 0 ile {limit.normalize()} arasında olmalıdır."
        )
    conversion = conversions.get((canonical_food_id, unit))
    if conversion is None:
        raise NutritionDomainError(
            "Bu besin ve birim için doğrulanmış gram dönüşümü bulunmuyor."
        )
    return validate_portion_grams(amount * conversion.grams_per_unit)
