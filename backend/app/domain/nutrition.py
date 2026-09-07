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
    ("artichoke", "en"): ("food.artichoke", "artichoke", "Enginar"),
    ("enginar", "tr"): ("food.artichoke", "artichoke", "Enginar"),
    ("anchovy", "en"): ("food.anchovy", "anchovy", "Hamsi"),
    ("hamsi", "tr"): ("food.anchovy", "anchovy", "Hamsi"),
    ("rice_with_oil", "en"): ("food.rice_with_oil", "rice_with_oil", "Pirinç pilavı"),
    ("pirinc_pilavi", "tr"): ("food.rice_with_oil", "rice_with_oil", "Pirinç pilavı"),
    ("stuffed_pepper", "en"): ("food.stuffed_pepper", "stuffed_pepper", "Biber dolması"),
    ("biber_dolmasi", "tr"): ("food.stuffed_pepper", "stuffed_pepper", "Biber dolması"),
    ("dolma", "tr"): ("food.stuffed_pepper", "stuffed_pepper", "Biber dolması"),
    ("stuffed_grape_leaves", "en"): ("food.stuffed_grape_leaves", "stuffed_grape_leaves", "Yaprak sarma"),
    ("yaprak_sarma", "tr"): ("food.stuffed_grape_leaves", "stuffed_grape_leaves", "Yaprak sarma"),
    ("sarma", "tr"): ("food.stuffed_grape_leaves", "stuffed_grape_leaves", "Yaprak sarma"),
    ("shish_kebab", "en"): ("food.shish_kebab", "shish_kebab", "Şiş kebap"),
    ("kebap", "tr"): ("food.shish_kebab", "shish_kebab", "Şiş kebap"),
    ("sis_kebap", "tr"): ("food.shish_kebab", "shish_kebab", "Şiş kebap"),
    ("eggplant_meat_casserole", "en"): ("food.eggplant_meat_casserole", "eggplant_meat_casserole", "Patlıcanlı et yemeği"),
    ("karniyarik", "tr"): ("food.eggplant_meat_casserole", "eggplant_meat_casserole", "Patlıcanlı et yemeği"),
    ("beef_stew_meat", "en"): ("food.beef_stew_meat", "beef_stew_meat", "Et sote"),
    ("et_sote", "tr"): ("food.beef_stew_meat", "beef_stew_meat", "Et sote"),
    ("tabbouleh", "en"): ("food.tabbouleh", "tabbouleh", "Kısır benzeri bulgur salatası"),
    ("tabbouleh", "tr"): ("food.tabbouleh", "tabbouleh", "Tabbouleh"),
    ("steamed_dumpling", "en"): ("food.steamed_dumpling", "steamed_dumpling", "Mantı benzeri hamur"),
    ("gummy_candy", "en"): ("food.gummy_candy", "gummy_candy", "Lokum benzeri jel şeker"),
    ("cooked_spinach", "en"): ("food.cooked_spinach", "cooked_spinach", "Ispanak"),
    ("ispanak", "tr"): ("food.cooked_spinach", "cooked_spinach", "Ispanak"),
    ("cooked_green_beans", "en"): ("food.cooked_green_beans", "cooked_green_beans", "Taze fasulye"),
    ("taze_fasulye", "tr"): ("food.cooked_green_beans", "cooked_green_beans", "Taze fasulye"),
    ("fritter", "en"): ("food.fritter", "fritter", "Mücver benzeri kızartma"),
    ("izmir_kofte", "tr"): ("food.meatballs", "meatballs", "Köfte"),
    ("lima_beans2", "en"): ("food.lima_beans2", "lima_beans2", "Lima fasulyesi"),
    ("lima_fasulyesi", "tr"): ("food.lima_beans2", "lima_beans2", "Lima fasulyesi"),
    ("buttermilk", "en"): ("food.buttermilk", "buttermilk", "Yayık ayranı"),
    ("yayik_ayrani", "tr"): ("food.buttermilk", "buttermilk", "Yayık ayranı"),
    ("kefir", "en"): ("food.kefir", "kefir", "Kefir"),
    ("kefir", "tr"): ("food.kefir", "kefir", "Kefir"),
    ("goat_milk", "en"): ("food.goat_milk", "goat_milk", "Keçi sütü"),
    ("keci_sutu", "tr"): ("food.goat_milk", "goat_milk", "Keçi sütü"),
    ("oat_milk", "en"): ("food.oat_milk", "oat_milk", "Yulaf sütü"),
    ("yulaf_sutu", "tr"): ("food.oat_milk", "oat_milk", "Yulaf sütü"),
    ("greek_yogurt", "en"): ("food.greek_yogurt", "greek_yogurt", "Süzme yoğurt"),
    ("suzme_yogurt", "tr"): ("food.greek_yogurt", "greek_yogurt", "Süzme yoğurt"),
    ("cream", "en"): ("food.cream", "cream", "Krema"),
    ("krema", "tr"): ("food.cream", "cream", "Krema"),
    ("rice_pudding", "en"): ("food.rice_pudding", "rice_pudding", "Sütlaç benzeri pirinç muhallebisi"),
    ("sutlac_benzeri_pirinc_muhallebisi", "tr"): ("food.rice_pudding", "rice_pudding", "Sütlaç benzeri pirinç muhallebisi"),
    ("kasar_benzeri_peynir", "tr"): ("food.cheddar_cheese", "cheddar_cheese", "Kaşar benzeri peynir"),
    ("mozzarella", "en"): ("food.mozzarella", "mozzarella", "Mozzarella peyniri"),
    ("mozzarella_peyniri", "tr"): ("food.mozzarella", "mozzarella", "Mozzarella peyniri"),
    ("parmesan", "en"): ("food.parmesan", "parmesan", "Parmesan peyniri"),
    ("parmesan_peyniri", "tr"): ("food.parmesan", "parmesan", "Parmesan peyniri"),
    ("beef", "en"): ("food.beef", "beef", "Dana eti"),
    ("dana_eti", "tr"): ("food.beef", "beef", "Dana eti"),
    ("et_sote_icin_dana_eti", "tr"): ("food.beef_stew_meat", "beef_stew_meat", "Et sote için dana eti"),
    ("goat", "en"): ("food.goat", "goat", "Keçi eti"),
    ("keci_eti", "tr"): ("food.goat", "goat", "Keçi eti"),
    ("veal", "en"): ("food.veal", "veal", "Dana pirzola"),
    ("dana_pirzola", "tr"): ("food.veal", "veal", "Dana pirzola"),
    ("chicken_wing", "en"): ("food.chicken_wing", "chicken_wing", "Tavuk kanat"),
    ("tavuk_kanat", "tr"): ("food.chicken_wing", "chicken_wing", "Tavuk kanat"),
    ("turkey", "en"): ("food.turkey", "turkey", "Hindi eti"),
    ("hindi_eti", "tr"): ("food.turkey", "turkey", "Hindi eti"),
    ("liver", "en"): ("food.liver", "liver", "Dana ciğeri"),
    ("dana_cigeri", "tr"): ("food.liver", "liver", "Dana ciğeri"),
    ("salami", "en"): ("food.salami", "salami", "Salam"),
    ("salam", "tr"): ("food.salami", "salami", "Salam"),
    ("salmon", "en"): ("food.salmon", "salmon", "Somon"),
    ("somon", "tr"): ("food.salmon", "salmon", "Somon"),
    ("sardines", "en"): ("food.sardines", "sardines", "Sardalya"),
    ("sardalya", "tr"): ("food.sardines", "sardines", "Sardalya"),
    ("tuna", "en"): ("food.tuna", "tuna", "Ton balığı"),
    ("ton_baligi", "tr"): ("food.tuna", "tuna", "Ton balığı"),
    ("squid", "en"): ("food.squid", "squid", "Ahtapot"),
    ("ahtapot", "tr"): ("food.squid", "squid", "Ahtapot"),
    ("crab", "en"): ("food.crab", "crab", "Yengeç"),
    ("yengec", "tr"): ("food.crab", "crab", "Yengeç"),
    ("mussels", "en"): ("food.mussels", "mussels", "Midye"),
    ("midye", "tr"): ("food.mussels", "mussels", "Midye"),
    ("kuru_fasulye", "tr"): ("food.white_beans", "white_beans", "Kuru fasulye"),
    ("cashews", "en"): ("food.cashews", "cashews", "Kaju"),
    ("kaju", "tr"): ("food.cashews", "cashews", "Kaju"),
    ("chestnuts", "en"): ("food.chestnuts", "chestnuts", "Kestane"),
    ("kestane", "tr"): ("food.chestnuts", "chestnuts", "Kestane"),
    ("peanuts", "en"): ("food.peanuts", "peanuts", "Yer fıstığı"),
    ("yer_fistigi", "tr"): ("food.peanuts", "peanuts", "Yer fıstığı"),
    ("pine_nuts", "en"): ("food.pine_nuts", "pine_nuts", "Çam fıstığı"),
    ("cam_fistigi", "tr"): ("food.pine_nuts", "pine_nuts", "Çam fıstığı"),
    ("pumpkin_seeds", "en"): ("food.pumpkin_seeds", "pumpkin_seeds", "Kabak çekirdeği"),
    ("kabak_cekirdegi", "tr"): ("food.pumpkin_seeds", "pumpkin_seeds", "Kabak çekirdeği"),
    ("sunflower_seeds", "en"): ("food.sunflower_seeds", "sunflower_seeds", "Ay çekirdeği"),
    ("ay_cekirdegi", "tr"): ("food.sunflower_seeds", "sunflower_seeds", "Ay çekirdeği"),
    ("tahini", "en"): ("food.tahini", "tahini", "Tahin"),
    ("tahin", "tr"): ("food.tahini", "tahini", "Tahin"),
    ("flax_seeds", "en"): ("food.flax_seeds", "flax_seeds", "Keten tohumu"),
    ("keten_tohumu", "tr"): ("food.flax_seeds", "flax_seeds", "Keten tohumu"),
    ("chia_seeds", "en"): ("food.chia_seeds", "chia_seeds", "Chia tohumu"),
    ("chia_tohumu", "tr"): ("food.chia_seeds", "chia_seeds", "Chia tohumu"),
    ("croissant", "en"): ("food.croissant", "croissant", "Kruvasan"),
    ("kruvasan", "tr"): ("food.croissant", "croissant", "Kruvasan"),
    ("rye_bread", "en"): ("food.rye_bread", "rye_bread", "Çavdar ekmeği"),
    ("cavdar_ekmegi", "tr"): ("food.rye_bread", "rye_bread", "Çavdar ekmeği"),
    ("cornbread", "en"): ("food.cornbread", "cornbread", "Mısır ekmeği"),
    ("misir_ekmegi", "tr"): ("food.cornbread", "cornbread", "Mısır ekmeği"),
    ("cake_plain", "en"): ("food.cake_plain", "cake_plain", "Kek"),
    ("kek", "tr"): ("food.cake_plain", "cake_plain", "Kek"),
    ("cookie", "en"): ("food.cookie", "cookie", "Bisküvi"),
    ("biskuvi", "tr"): ("food.cookie", "cookie", "Bisküvi"),
    ("mucver_benzeri_kizartma", "tr"): ("food.fritter", "fritter", "Mücver benzeri kızartma"),
    ("doughnut", "en"): ("food.doughnut", "doughnut", "Donut"),
    ("donut", "tr"): ("food.doughnut", "doughnut", "Donut"),
    ("crackers", "en"): ("food.crackers", "crackers", "Kraker"),
    ("kraker", "tr"): ("food.crackers", "crackers", "Kraker"),
    ("rice_cake", "en"): ("food.rice_cake", "rice_cake", "Pirinç patlağı"),
    ("pirinc_patlagi", "tr"): ("food.rice_cake", "rice_cake", "Pirinç patlağı"),
    ("pita_chips", "en"): ("food.pita_chips", "pita_chips", "Pide cipsi"),
    ("pide_cipsi", "tr"): ("food.pita_chips", "pita_chips", "Pide cipsi"),
    ("popcorn", "en"): ("food.popcorn", "popcorn", "Patlamış mısır"),
    ("patlamis_misir", "tr"): ("food.popcorn", "popcorn", "Patlamış mısır"),
    ("pancake", "en"): ("food.pancake", "pancake", "Krep/pankek"),
    ("krep_pankek", "tr"): ("food.pancake", "pancake", "Krep/pankek"),
    ("waffle", "en"): ("food.waffle", "waffle", "Waffle"),
    ("waffle", "tr"): ("food.waffle", "waffle", "Waffle"),
    ("noodles", "en"): ("food.noodles", "noodles", "Erişte"),
    ("eriste", "tr"): ("food.noodles", "noodles", "Erişte"),
    ("barley", "en"): ("food.barley", "barley", "Arpa"),
    ("arpa", "tr"): ("food.barley", "barley", "Arpa"),
    ("millet", "en"): ("food.millet", "millet", "Darı"),
    ("dari", "tr"): ("food.millet", "millet", "Darı"),
    ("oatmeal", "en"): ("food.oatmeal", "oatmeal", "Yulaf ezmesi"),
    ("yulaf_ezmesi", "tr"): ("food.oatmeal", "oatmeal", "Yulaf ezmesi"),
    ("esmer_pirinc_pilavi", "tr"): ("food.brown_rice", "brown_rice", "Esmer pirinç pilavı"),
    ("corn_flakes", "en"): ("food.corn_flakes", "corn_flakes", "Mısır gevreği"),
    ("misir_gevregi", "tr"): ("food.corn_flakes", "corn_flakes", "Mısır gevreği"),
    ("buharda_manti_benzeri_hamur", "tr"): ("food.steamed_dumpling", "steamed_dumpling", "Buharda mantı benzeri hamur"),
    ("peynirli_borek_benzeri_hamur_isi", "tr"): ("food.cheese_pastry", "cheese_pastry", "Peynirli börek benzeri hamur işi"),
    ("kisir_benzeri_bulgur_salatasi", "tr"): ("food.tabbouleh", "tabbouleh", "Kısır benzeri bulgur salatası"),
    ("tavuklu_sehriye_corbasi", "tr"): ("food.chicken_noodle_soup", "chicken_noodle_soup", "Tavuklu şehriye çorbası"),
    ("lemon", "en"): ("food.lemon", "lemon", "Limon"),
    ("limon", "tr"): ("food.lemon", "lemon", "Limon"),
    ("tangerine", "en"): ("food.tangerine", "tangerine", "Mandalina"),
    ("mandalina", "tr"): ("food.tangerine", "tangerine", "Mandalina"),
    ("dried_apricot", "en"): ("food.dried_apricot", "dried_apricot", "Kuru kayısı"),
    ("kuru_kayisi", "tr"): ("food.dried_apricot", "dried_apricot", "Kuru kayısı"),
    ("date_fruit", "en"): ("food.date_fruit", "date_fruit", "Hurma"),
    ("hurma", "tr"): ("food.date_fruit", "date_fruit", "Hurma"),
    ("dried_fig", "en"): ("food.dried_fig", "dried_fig", "Kuru incir"),
    ("kuru_incir", "tr"): ("food.dried_fig", "dried_fig", "Kuru incir"),
    ("avocado", "en"): ("food.avocado", "avocado", "Avokado"),
    ("avokado", "tr"): ("food.avocado", "avocado", "Avokado"),
    ("cantaloupe", "en"): ("food.cantaloupe", "cantaloupe", "Kavun"),
    ("kavun", "tr"): ("food.cantaloupe", "cantaloupe", "Kavun"),
    ("kiwi", "en"): ("food.kiwi", "kiwi", "Kivi"),
    ("kivi", "tr"): ("food.kiwi", "kiwi", "Kivi"),
    ("peach", "en"): ("food.peach", "peach", "Şeftali"),
    ("seftali", "tr"): ("food.peach", "peach", "Şeftali"),
    ("pear", "en"): ("food.pear", "pear", "Armut"),
    ("armut", "tr"): ("food.pear", "pear", "Armut"),
    ("pineapple", "en"): ("food.pineapple", "pineapple", "Ananas"),
    ("ananas", "tr"): ("food.pineapple", "pineapple", "Ananas"),
    ("plum", "en"): ("food.plum", "plum", "Erik"),
    ("erik", "tr"): ("food.plum", "plum", "Erik"),
    ("pomegranate", "en"): ("food.pomegranate", "pomegranate", "Nar"),
    ("nar", "tr"): ("food.pomegranate", "pomegranate", "Nar"),
    ("blueberries", "en"): ("food.blueberries", "blueberries", "Yaban mersini"),
    ("yaban_mersini", "tr"): ("food.blueberries", "blueberries", "Yaban mersini"),
    ("raspberries", "en"): ("food.raspberries", "raspberries", "Ahududu"),
    ("ahududu", "tr"): ("food.raspberries", "raspberries", "Ahududu"),
    ("potato_chips", "en"): ("food.potato_chips", "potato_chips", "Patates cipsi"),
    ("patates_cipsi", "tr"): ("food.potato_chips", "potato_chips", "Patates cipsi"),
    ("chard", "en"): ("food.chard", "chard", "Pazı"),
    ("pazi", "tr"): ("food.chard", "chard", "Pazı"),
    ("kale", "en"): ("food.kale", "kale", "Kara lahana"),
    ("kara_lahana", "tr"): ("food.kale", "kale", "Kara lahana"),
    ("broccoli", "en"): ("food.broccoli", "broccoli", "Brokoli"),
    ("brokoli", "tr"): ("food.broccoli", "broccoli", "Brokoli"),
    ("peas_cooked", "en"): ("food.peas_cooked", "peas_cooked", "Bezelye ve havuç"),
    ("bezelye_ve_havuc", "tr"): ("food.peas_cooked", "peas_cooked", "Bezelye ve havuç"),
    ("sweet_potato", "en"): ("food.sweet_potato", "sweet_potato", "Tatlı patates"),
    ("tatli_patates", "tr"): ("food.sweet_potato", "sweet_potato", "Tatlı patates"),
    ("ketchup", "en"): ("food.ketchup", "ketchup", "Ketçap"),
    ("ketcap", "tr"): ("food.ketchup", "ketchup", "Ketçap"),
    ("beet", "en"): ("food.beet", "beet", "Pancar"),
    ("pancar", "tr"): ("food.beet", "beet", "Pancar"),
    ("cabbage", "en"): ("food.cabbage", "cabbage", "Kırmızı lahana"),
    ("kirmizi_lahana", "tr"): ("food.cabbage", "cabbage", "Kırmızı lahana"),
    ("cauliflower", "en"): ("food.cauliflower", "cauliflower", "Karnabahar"),
    ("karnabahar", "tr"): ("food.cauliflower", "cauliflower", "Karnabahar"),
    ("celery", "en"): ("food.celery", "celery", "Kereviz sapı"),
    ("kereviz_sapi", "tr"): ("food.celery", "celery", "Kereviz sapı"),
    ("corn_cooked", "en"): ("food.corn_cooked", "corn_cooked", "Mısır"),
    ("misir", "tr"): ("food.corn_cooked", "corn_cooked", "Mısır"),
    ("mushrooms", "en"): ("food.mushrooms", "mushrooms", "Mantar"),
    ("mantar", "tr"): ("food.mushrooms", "mushrooms", "Mantar"),
    ("radish", "en"): ("food.radish", "radish", "Turp"),
    ("turp", "tr"): ("food.radish", "radish", "Turp"),
    ("mustard", "en"): ("food.mustard", "mustard", "Hardal"),
    ("hardal", "tr"): ("food.mustard", "mustard", "Hardal"),
    ("yesil_zeytin", "tr"): ("food.green_olives", "green_olives", "Yeşil zeytin"),
    ("black_olives", "en"): ("food.black_olives", "black_olives", "Siyah zeytin"),
    ("siyah_zeytin", "tr"): ("food.black_olives", "black_olives", "Siyah zeytin"),
    ("pickles", "en"): ("food.pickles", "pickles", "Turşu"),
    ("tursu", "tr"): ("food.pickles", "pickles", "Turşu"),
    ("patlicanli_et_yemegi", "tr"): ("food.eggplant_meat_casserole", "eggplant_meat_casserole", "Patlıcanlı et yemeği"),
    ("corn_oil", "en"): ("food.corn_oil", "corn_oil", "Mısır yağı"),
    ("misir_yagi", "tr"): ("food.corn_oil", "corn_oil", "Mısır yağı"),
    ("sunflower_oil", "en"): ("food.sunflower_oil", "sunflower_oil", "Ayçiçek yağı"),
    ("aycicek_yagi", "tr"): ("food.sunflower_oil", "sunflower_oil", "Ayçiçek yağı"),
    ("mayonnaise", "en"): ("food.mayonnaise", "mayonnaise", "Mayonez"),
    ("mayonez", "tr"): ("food.mayonnaise", "mayonnaise", "Mayonez"),
    ("tomato_sauce", "en"): ("food.tomato_sauce", "tomato_sauce", "Domates sosu"),
    ("domates_sosu", "tr"): ("food.tomato_sauce", "tomato_sauce", "Domates sosu"),
    ("chocolate", "en"): ("food.chocolate", "chocolate", "Çikolata"),
    ("cikolata", "tr"): ("food.chocolate", "chocolate", "Çikolata"),
    ("lokum_benzeri_jel_seker", "tr"): ("food.gummy_candy", "gummy_candy", "Lokum benzeri jel şeker"),
    ("icli_kofte", "en"): ("food.icli_kofte", "icli_kofte", "Icli kofte"),
    ("icli_kofte", "tr"): ("food.icli_kofte", "icli_kofte", "Icli kofte"),
    ("kisir", "en"): ("food.kisir", "kisir", "Kisir"),
    ("kisir", "tr"): ("food.kisir", "kisir", "Kisir"),
    ("kuru_fasulye", "en"): ("food.kuru_fasulye", "kuru_fasulye", "Kuru fasulye yemegi"),
    ("kuru_fasulye_yemegi", "tr"): ("food.kuru_fasulye", "kuru_fasulye", "Kuru fasulye yemegi"),
    ("gozleme", "en"): ("food.gozleme", "gozleme", "Gozleme"),
    ("gozleme", "tr"): ("food.gozleme", "gozleme", "Gozleme"),
    ("mucver", "en"): ("food.mucver", "mucver", "Mucver"),
    ("mucver", "tr"): ("food.mucver", "mucver", "Mucver"),
    ("hunkar_begendi", "en"): ("food.hunkar_begendi", "hunkar_begendi", "Hunkar begendi"),
    ("hunkar_begendi", "tr"): ("food.hunkar_begendi", "hunkar_begendi", "Hunkar begendi"),
    ("cig_kofte", "en"): ("food.cig_kofte", "cig_kofte", "Cig kofte"),
    ("cig_kofte", "tr"): ("food.cig_kofte", "cig_kofte", "Cig kofte"),
    ("asure", "en"): ("food.asure", "asure", "Asure"),
    ("asure", "tr"): ("food.asure", "asure", "Asure"),
    ("lokum", "en"): ("food.lokum", "lokum", "Lokum"),
    ("lokum", "tr"): ("food.lokum", "lokum", "Lokum"),
    ("beef_sausage", "en"): ("food.beef_sausage", "beef_sausage", "Dana sucuk benzeri sosis"),
    ("dana_sucuk_benzeri_sosis", "tr"): ("food.beef_sausage", "beef_sausage", "Dana sucuk benzeri sosis"),
    ("pastrami", "en"): ("food.pastrami", "pastrami", "Pastırma benzeri"),
    ("pastirma_benzeri", "tr"): ("food.pastrami", "pastrami", "Pastırma benzeri"),
    ("fried_egg", "en"): ("food.fried_egg", "fried_egg", "Yumurta"),
    ("split_peas", "en"): ("food.split_peas", "split_peas", "Kuru bezelye"),
    ("kuru_bezelye", "tr"): ("food.split_peas", "split_peas", "Kuru bezelye"),
    ("lentils_nfs", "en"): ("food.lentils_nfs", "lentils_nfs", "Yeşil mercimek"),
    ("yesil_mercimek", "tr"): ("food.lentils_nfs", "lentils_nfs", "Yeşil mercimek"),
    ("bulgur_with_fat", "en"): ("food.bulgur_with_fat", "bulgur_with_fat", "Bulgur pilavı"),
    ("bulgur_pilavi", "tr"): ("food.bulgur_with_fat", "bulgur_with_fat", "Bulgur pilavı"),
    ("egg_roll", "en"): ("food.egg_roll", "egg_roll", "Sigara böreği benzeri rulo"),
    ("sigara_boregi_benzeri_rulo", "tr"): ("food.egg_roll", "egg_roll", "Sigara böreği benzeri rulo"),
    ("grapefruit", "en"): ("food.grapefruit", "grapefruit", "Greyfurt"),
    ("greyfurt", "tr"): ("food.grapefruit", "grapefruit", "Greyfurt"),
    ("lemon_juice", "en"): ("food.lemon_juice", "lemon_juice", "Limon suyu"),
    ("limon_suyu", "tr"): ("food.lemon_juice", "lemon_juice", "Limon suyu"),
    ("romaine", "en"): ("food.romaine", "romaine", "Kıvırcık marul"),
    ("kivircik_marul", "tr"): ("food.romaine", "romaine", "Kıvırcık marul"),
    ("raw_spinach", "en"): ("food.raw_spinach", "raw_spinach", "Ispanak"),
    ("pumpkin", "en"): ("food.pumpkin", "pumpkin", "Balkabağı"),
    ("balkabagi", "tr"): ("food.pumpkin", "pumpkin", "Balkabağı"),
    ("green_cabbage", "en"): ("food.green_cabbage", "green_cabbage", "Beyaz lahana"),
    ("beyaz_lahana", "tr"): ("food.green_cabbage", "green_cabbage", "Beyaz lahana"),
    ("garlic", "en"): ("food.garlic", "garlic", "Sarımsak"),
    ("sarimsak", "tr"): ("food.garlic", "garlic", "Sarımsak"),
    ("parsley", "en"): ("food.parsley", "parsley", "Maydanoz"),
    ("maydanoz", "tr"): ("food.parsley", "parsley", "Maydanoz"),
    ("red_pepper", "en"): ("food.red_pepper", "red_pepper", "Kırmızı biber"),
    ("kirmizi_biber", "tr"): ("food.red_pepper", "red_pepper", "Kırmızı biber"),
    ("jelly", "en"): ("food.jelly", "jelly", "Jöle reçeli"),
    ("jole_receli", "tr"): ("food.jelly", "jelly", "Jöle reçeli"),
    ("milk_nfs", "en"): ("food.milk_nfs", "milk_nfs", "Süt"),
    ("kefir2", "en"): ("food.kefir2", "kefir2", "Kefir"),
    ("goat_milk2", "en"): ("food.goat_milk2", "goat_milk2", "Keçi sütü"),
    ("rice_milk", "en"): ("food.rice_milk", "rice_milk", "Pirinç sütü"),
    ("pirinc_sutu", "tr"): ("food.rice_milk", "rice_milk", "Pirinç sütü"),
    ("oat_milk2", "en"): ("food.oat_milk2", "oat_milk2", "Yulaf sütü"),
    ("frozen_yogurt", "en"): ("food.frozen_yogurt", "frozen_yogurt", "Donmuş yoğurt"),
    ("donmus_yogurt", "tr"): ("food.frozen_yogurt", "frozen_yogurt", "Donmuş yoğurt"),
    ("eggnog", "en"): ("food.eggnog", "eggnog", "Yumurtalı süt"),
    ("yumurtali_sut", "tr"): ("food.eggnog", "eggnog", "Yumurtalı süt"),
    ("cream_light", "en"): ("food.cream_light", "cream_light", "Krema"),
    ("whipped_cream", "en"): ("food.whipped_cream", "whipped_cream", "Çırpılmış krema"),
    ("cirpilmis_krema", "tr"): ("food.whipped_cream", "whipped_cream", "Çırpılmış krema"),
    ("whipped_topping", "en"): ("food.whipped_topping", "whipped_topping", "Krema şantisi"),
    ("krema_santisi", "tr"): ("food.whipped_topping", "whipped_topping", "Krema şantisi"),
    ("sour_cream", "en"): ("food.sour_cream", "sour_cream", "Ekşi krema"),
    ("eksi_krema", "tr"): ("food.sour_cream", "sour_cream", "Ekşi krema"),
    ("dip", "en"): ("food.dip", "dip", "Meze sosu"),
    ("meze_sosu", "tr"): ("food.dip", "dip", "Meze sosu"),
    ("onion_dip", "en"): ("food.onion_dip", "onion_dip", "Soğanlı sos"),
    ("soganli_sos", "tr"): ("food.onion_dip", "onion_dip", "Soğanlı sos"),
    ("gelato", "en"): ("food.gelato", "gelato", "Gelato"),
    ("gelato", "tr"): ("food.gelato", "gelato", "Gelato"),
    ("gelato_chocolate", "en"): ("food.gelato_chocolate", "gelato_chocolate", "Gelato"),
    ("banana_split", "en"): ("food.banana_split", "banana_split", "Muzlu dondurma"),
    ("muzlu_dondurma", "tr"): ("food.banana_split", "banana_split", "Muzlu dondurma"),
    ("fried_ice_cream", "en"): ("food.fried_ice_cream", "fried_ice_cream", "Kızarmış dondurma"),
    ("kizarmis_dondurma", "tr"): ("food.fried_ice_cream", "fried_ice_cream", "Kızarmış dondurma"),
    ("creamsicle", "en"): ("food.creamsicle", "creamsicle", "Portakallı dondurma çubuğu"),
    ("portakalli_dondurma_cubugu", "tr"): ("food.creamsicle", "creamsicle", "Portakallı dondurma çubuğu"),
    ("fudgesicle", "en"): ("food.fudgesicle", "fudgesicle", "Çikolatalı dondurma çubuğu"),
    ("cikolatali_dondurma_cubugu", "tr"): ("food.fudgesicle", "fudgesicle", "Çikolatalı dondurma çubuğu"),
    ("tiramisu", "en"): ("food.tiramisu", "tiramisu", "Tiramisu"),
    ("tiramisu", "tr"): ("food.tiramisu", "tiramisu", "Tiramisu"),
    ("cheese_nfs", "en"): ("food.cheese_nfs", "cheese_nfs", "Peynir"),
    ("cheese_brick", "en"): ("food.cheese_brick", "cheese_brick", "Brick peyniri"),
    ("brick_peyniri", "tr"): ("food.cheese_brick", "cheese_brick", "Brick peyniri"),
    ("cheese_camembert", "en"): ("food.cheese_camembert", "cheese_camembert", "Camembert peyniri"),
    ("camembert_peyniri", "tr"): ("food.cheese_camembert", "cheese_camembert", "Camembert peyniri"),
    ("cheese_brie", "en"): ("food.cheese_brie", "cheese_brie", "Brie peyniri"),
    ("brie_peyniri", "tr"): ("food.cheese_brie", "cheese_brie", "Brie peyniri"),
    ("cheese_colby", "en"): ("food.cheese_colby", "cheese_colby", "Colby peyniri"),
    ("colby_peyniri", "tr"): ("food.cheese_colby", "cheese_colby", "Colby peyniri"),
    ("cheese_colby_jack", "en"): ("food.cheese_colby_jack", "cheese_colby_jack", "Colby Jack peyniri"),
    ("colby_jack_peyniri", "tr"): ("food.cheese_colby_jack", "cheese_colby_jack", "Colby Jack peyniri"),
    ("cheese_fontina", "en"): ("food.cheese_fontina", "cheese_fontina", "Fontina peyniri"),
    ("fontina_peyniri", "tr"): ("food.cheese_fontina", "cheese_fontina", "Fontina peyniri"),
    ("cheese_goat", "en"): ("food.cheese_goat", "cheese_goat", "Keçi peyniri"),
    ("keci_peyniri", "tr"): ("food.cheese_goat", "cheese_goat", "Keçi peyniri"),
    ("cheese_gruyere", "en"): ("food.cheese_gruyere", "cheese_gruyere", "Gruyere peyniri"),
    ("gruyere_peyniri", "tr"): ("food.cheese_gruyere", "cheese_gruyere", "Gruyere peyniri"),
    ("cheese_monterey", "en"): ("food.cheese_monterey", "cheese_monterey", "Monterey peyniri"),
    ("monterey_peyniri", "tr"): ("food.cheese_monterey", "cheese_monterey", "Monterey peyniri"),
    ("cheese_muenster", "en"): ("food.cheese_muenster", "cheese_muenster", "Muenster peyniri"),
    ("muenster_peyniri", "tr"): ("food.cheese_muenster", "cheese_muenster", "Muenster peyniri"),
    ("cheese_provolone", "en"): ("food.cheese_provolone", "cheese_provolone", "Provolone peyniri"),
    ("provolone_peyniri", "tr"): ("food.cheese_provolone", "cheese_provolone", "Provolone peyniri"),
    ("cheese_swiss", "en"): ("food.cheese_swiss", "cheese_swiss", "İsviçre peyniri"),
    ("isvicre_peyniri", "tr"): ("food.cheese_swiss", "cheese_swiss", "İsviçre peyniri"),
    ("cheese_paneer", "en"): ("food.cheese_paneer", "cheese_paneer", "Paneer peyniri"),
    ("paneer_peyniri", "tr"): ("food.cheese_paneer", "cheese_paneer", "Paneer peyniri"),
    ("queso_fresco", "en"): ("food.queso_fresco", "queso_fresco", "Taze beyaz peynir"),
    ("taze_beyaz_peynir", "tr"): ("food.queso_fresco", "queso_fresco", "Taze beyaz peynir"),
    ("queso_cotija", "en"): ("food.queso_cotija", "queso_cotija", "Cotija peyniri"),
    ("cotija_peyniri", "tr"): ("food.queso_cotija", "queso_cotija", "Cotija peyniri"),
    ("cheese_ricotta", "en"): ("food.cheese_ricotta", "cheese_ricotta", "Ricotta peyniri"),
    ("ricotta_peyniri", "tr"): ("food.cheese_ricotta", "cheese_ricotta", "Ricotta peyniri"),
    ("cheese_american", "en"): ("food.cheese_american", "cheese_american", "Amerikan peyniri"),
    ("amerikan_peyniri", "tr"): ("food.cheese_american", "cheese_american", "Amerikan peyniri"),
    ("cheese_ball", "en"): ("food.cheese_ball", "cheese_ball", "Peynir topu"),
    ("peynir_topu", "tr"): ("food.cheese_ball", "cheese_ball", "Peynir topu"),
    ("cheese_dip", "en"): ("food.cheese_dip", "cheese_dip", "Peynirli sos"),
    ("peynirli_sos", "tr"): ("food.cheese_dip", "cheese_dip", "Peynirli sos"),
    ("beef_steak", "en"): ("food.beef_steak", "beef_steak", "Dana biftek"),
    ("dana_biftek", "tr"): ("food.beef_steak", "beef_steak", "Dana biftek"),
    ("beef_steak_cube", "en"): ("food.beef_steak_cube", "beef_steak_cube", "Kuşbaşı dana"),
    ("kusbasi_dana", "tr"): ("food.beef_steak_cube", "beef_steak_cube", "Kuşbaşı dana"),
    ("beef_steak_flank", "en"): ("food.beef_steak_flank", "beef_steak_flank", "Dana pirzola eti"),
    ("dana_pirzola_eti", "tr"): ("food.beef_steak_flank", "beef_steak_flank", "Dana pirzola eti"),
    ("oxtail", "en"): ("food.oxtail", "oxtail", "Kuyruk eti"),
    ("kuyruk_eti", "tr"): ("food.oxtail", "oxtail", "Kuyruk eti"),
    ("beef_shortribs", "en"): ("food.beef_shortribs", "beef_shortribs", "Dana kaburga"),
    ("dana_kaburga", "tr"): ("food.beef_shortribs", "beef_shortribs", "Dana kaburga"),
    ("beef_roast", "en"): ("food.beef_roast", "beef_roast", "Rosto dana"),
    ("rosto_dana", "tr"): ("food.beef_roast", "beef_roast", "Rosto dana"),
    ("beef_pot_roast", "en"): ("food.beef_pot_roast", "beef_pot_roast", "Dana haşlama rosto"),
    ("dana_haslama_rosto", "tr"): ("food.beef_pot_roast", "beef_pot_roast", "Dana haşlama rosto"),
    ("corned_beef", "en"): ("food.corned_beef", "corned_beef", "Salamura dana"),
    ("salamura_dana", "tr"): ("food.corned_beef", "corned_beef", "Salamura dana"),
    ("beef_brisket", "en"): ("food.beef_brisket", "beef_brisket", "Dana döş"),
    ("dana_dos", "tr"): ("food.beef_brisket", "beef_brisket", "Dana döş"),
    ("pork", "en"): ("food.pork", "pork", "Domuz eti"),
    ("domuz_eti", "tr"): ("food.pork", "pork", "Domuz eti"),
    ("pork_ground", "en"): ("food.pork_ground", "pork_ground", "Domuz kıyma"),
    ("domuz_kiyma", "tr"): ("food.pork_ground", "pork_ground", "Domuz kıyma"),
    ("pork_tenderloin", "en"): ("food.pork_tenderloin", "pork_tenderloin", "Domuz bonfile"),
    ("domuz_bonfile", "tr"): ("food.pork_tenderloin", "pork_tenderloin", "Domuz bonfile"),
    ("pork_roast", "en"): ("food.pork_roast", "pork_roast", "Domuz rosto"),
    ("domuz_rosto", "tr"): ("food.pork_roast", "pork_roast", "Domuz rosto"),
    ("lamb_chop", "en"): ("food.lamb_chop", "lamb_chop", "Kuzu pirzola"),
    ("kuzu_pirzola", "tr"): ("food.lamb_chop", "lamb_chop", "Kuzu pirzola"),
    ("lamb_ground", "en"): ("food.lamb_ground", "lamb_ground", "Kuzu kıyma"),
    ("kuzu_kiyma", "tr"): ("food.lamb_ground", "lamb_ground", "Kuzu kıyma"),
    ("goat_meat", "en"): ("food.goat_meat", "goat_meat", "Keçi eti"),
    ("veal_chop2", "en"): ("food.veal_chop2", "veal_chop2", "Dana pirzola"),
    ("veal_ground", "en"): ("food.veal_ground", "veal_ground", "Dana kıyma"),
    ("rabbit", "en"): ("food.rabbit", "rabbit", "Tavşan eti"),
    ("tavsan_eti", "tr"): ("food.rabbit", "rabbit", "Tavşan eti"),
    ("ostrich", "en"): ("food.ostrich", "ostrich", "Deve kuşu eti"),
    ("deve_kusu_eti", "tr"): ("food.ostrich", "ostrich", "Deve kuşu eti"),
    ("chicken_skin", "en"): ("food.chicken_skin", "chicken_skin", "Tavuk derisi"),
    ("tavuk_derisi", "tr"): ("food.chicken_skin", "chicken_skin", "Tavuk derisi"),
    ("chicken_patty", "en"): ("food.chicken_patty", "chicken_patty", "Tavuk köftesi"),
    ("tavuk_koftesi", "tr"): ("food.chicken_patty", "chicken_patty", "Tavuk köftesi"),
    ("chicken_fillet_breaded", "en"): ("food.chicken_fillet_breaded", "chicken_fillet_breaded", "Pane tavuk fileto"),
    ("pane_tavuk_fileto", "tr"): ("food.chicken_fillet_breaded", "chicken_fillet_breaded", "Pane tavuk fileto"),
    ("chicken_fillet_grilled", "en"): ("food.chicken_fillet_grilled", "chicken_fillet_grilled", "Izgara tavuk fileto"),
    ("izgara_tavuk_fileto", "tr"): ("food.chicken_fillet_grilled", "chicken_fillet_grilled", "Izgara tavuk fileto"),
    ("chicken_nuggets", "en"): ("food.chicken_nuggets", "chicken_nuggets", "Tavuk nugget"),
    ("tavuk_nugget", "tr"): ("food.chicken_nuggets", "chicken_nuggets", "Tavuk nugget"),
    ("bratwurst", "en"): ("food.bratwurst", "bratwurst", "Bratwurst sosis"),
    ("bratwurst_sosis", "tr"): ("food.bratwurst", "bratwurst", "Bratwurst sosis"),
    ("chorizo", "en"): ("food.chorizo", "chorizo", "Chorizo sosis"),
    ("chorizo_sosis", "tr"): ("food.chorizo", "chorizo", "Chorizo sosis"),
    ("knockwurst", "en"): ("food.knockwurst", "knockwurst", "Knockwurst sosis"),
    ("knockwurst_sosis", "tr"): ("food.knockwurst", "knockwurst", "Knockwurst sosis"),
    ("thuringer", "en"): ("food.thuringer", "thuringer", "Thuringer sosis"),
    ("thuringer_sosis", "tr"): ("food.thuringer", "thuringer", "Thuringer sosis"),
    ("fish_raw", "en"): ("food.fish_raw", "fish_raw", "Balık"),
    ("fish_canned", "en"): ("food.fish_canned", "fish_canned", "Balık"),
    ("fish_smoked", "en"): ("food.fish_smoked", "fish_smoked", "Füme balık"),
    ("fume_balik", "tr"): ("food.fish_smoked", "fish_smoked", "Füme balık"),
    ("fish_stick", "en"): ("food.fish_stick", "fish_stick", "Balık kroketi"),
    ("balik_kroketi", "tr"): ("food.fish_stick", "fish_stick", "Balık kroketi"),
    ("fish_carp", "en"): ("food.fish_carp", "fish_carp", "Sazan"),
    ("sazan", "tr"): ("food.fish_carp", "fish_carp", "Sazan"),
    ("fish_cod", "en"): ("food.fish_cod", "fish_cod", "Morina"),
    ("morina", "tr"): ("food.fish_cod", "fish_cod", "Morina"),
    ("fish_croaker", "en"): ("food.fish_croaker", "fish_croaker", "Kötek balığı"),
    ("kotek_baligi", "tr"): ("food.fish_croaker", "fish_croaker", "Kötek balığı"),
    ("fish_eel", "en"): ("food.fish_eel", "fish_eel", "Yılan balığı"),
    ("yilan_baligi", "tr"): ("food.fish_eel", "fish_eel", "Yılan balığı"),
    ("fish_halibut", "en"): ("food.fish_halibut", "fish_halibut", "Halibut"),
    ("halibut", "tr"): ("food.fish_halibut", "fish_halibut", "Halibut"),
    ("fish_herring", "en"): ("food.fish_herring", "fish_herring", "Ringa"),
    ("ringa", "tr"): ("food.fish_herring", "fish_herring", "Ringa"),
    ("pickled_fish", "en"): ("food.pickled_fish", "pickled_fish", "Balık turşusu"),
    ("balik_tursusu", "tr"): ("food.pickled_fish", "pickled_fish", "Balık turşusu"),
    ("fish_mullet", "en"): ("food.fish_mullet", "fish_mullet", "Kefal"),
    ("kefal", "tr"): ("food.fish_mullet", "fish_mullet", "Kefal"),
    ("fish_pike", "en"): ("food.fish_pike", "fish_pike", "Turna balığı"),
    ("turna_baligi", "tr"): ("food.fish_pike", "fish_pike", "Turna balığı"),
    ("fish_snapper", "en"): ("food.fish_snapper", "fish_snapper", "Mercan balığı"),
    ("mercan_baligi", "tr"): ("food.fish_snapper", "fish_snapper", "Mercan balığı"),
    ("fish_bass", "en"): ("food.fish_bass", "fish_bass", "Levrek"),
    ("levrek", "tr"): ("food.fish_bass", "fish_bass", "Levrek"),
    ("fish_shark", "en"): ("food.fish_shark", "fish_shark", "Köpek balığı"),
    ("kopek_baligi", "tr"): ("food.fish_shark", "fish_shark", "Köpek balığı"),
    ("fish_swordfish", "en"): ("food.fish_swordfish", "fish_swordfish", "Kılıç balığı"),
    ("kilic_baligi", "tr"): ("food.fish_swordfish", "fish_swordfish", "Kılıç balığı"),
    ("octopus2", "en"): ("food.octopus2", "octopus2", "Ahtapot"),
    ("caviar", "en"): ("food.caviar", "caviar", "Havyar"),
    ("havyar", "tr"): ("food.caviar", "caviar", "Havyar"),
    ("abalone", "en"): ("food.abalone", "abalone", "Deniz kulağı"),
    ("deniz_kulagi", "tr"): ("food.abalone", "abalone", "Deniz kulağı"),
    ("clams", "en"): ("food.clams", "clams", "Deniz tarağı"),
    ("deniz_taragi", "tr"): ("food.clams", "clams", "Deniz tarağı"),
    ("clams_fried", "en"): ("food.clams_fried", "clams_fried", "Kızarmış deniz tarağı"),
    ("kizarmis_deniz_taragi", "tr"): ("food.clams_fried", "clams_fried", "Kızarmış deniz tarağı"),
    ("crab2", "en"): ("food.crab2", "crab2", "Yengeç"),
    ("lobster", "en"): ("food.lobster", "lobster", "Istakoz"),
    ("istakoz", "tr"): ("food.lobster", "lobster", "Istakoz"),
    ("mussels2", "en"): ("food.mussels2", "mussels2", "Midye"),
    ("chili", "en"): ("food.chili", "chili", "Acılı fasulyeli et"),
    ("acili_fasulyeli_et", "tr"): ("food.chili", "chili", "Acılı fasulyeli et"),
    ("beef_curry", "en"): ("food.beef_curry", "beef_curry", "Dana köri"),
    ("dana_kori", "tr"): ("food.beef_curry", "beef_curry", "Dana köri"),
    ("chicken_with_gravy", "en"): ("food.chicken_with_gravy", "chicken_with_gravy", "Soslu tavuk"),
    ("soslu_tavuk", "tr"): ("food.chicken_with_gravy", "chicken_with_gravy", "Soslu tavuk"),
    ("chicken_curry", "en"): ("food.chicken_curry", "chicken_curry", "Tavuk köri"),
    ("tavuk_kori", "tr"): ("food.chicken_curry", "chicken_curry", "Tavuk köri"),
    ("chicken_kiev", "en"): ("food.chicken_kiev", "chicken_kiev", "Kiev usulü tavuk"),
    ("kiev_usulu_tavuk", "tr"): ("food.chicken_kiev", "chicken_kiev", "Kiev usulü tavuk"),
    ("fish_curry", "en"): ("food.fish_curry", "fish_curry", "Balık körisi"),
    ("balik_korisi", "tr"): ("food.fish_curry", "fish_curry", "Balık körisi"),
    ("ceviche", "en"): ("food.ceviche", "ceviche", "Ceviche"),
    ("ceviche", "tr"): ("food.ceviche", "ceviche", "Ceviche"),
    ("fish_stew", "en"): ("food.fish_stew", "fish_stew", "Balık yahnisi"),
    ("balik_yahnisi", "tr"): ("food.fish_stew", "fish_stew", "Balık yahnisi"),
    ("crab_cake", "en"): ("food.crab_cake", "crab_cake", "Yengeç köftesi"),
    ("yengec_koftesi", "tr"): ("food.crab_cake", "crab_cake", "Yengeç köftesi"),
    ("gefilte_fish", "en"): ("food.gefilte_fish", "gefilte_fish", "Balık köftesi"),
    ("balik_koftesi", "tr"): ("food.gefilte_fish", "gefilte_fish", "Balık köftesi"),
    ("beef_stew", "en"): ("food.beef_stew", "beef_stew", "Dana yahnisi"),
    ("dana_yahnisi", "tr"): ("food.beef_stew", "beef_stew", "Dana yahnisi"),
    ("lamb_stew", "en"): ("food.lamb_stew", "lamb_stew", "Kuzu yahnisi"),
    ("kuzu_yahnisi", "tr"): ("food.lamb_stew", "lamb_stew", "Kuzu yahnisi"),
    ("stew_nfs", "en"): ("food.stew_nfs", "stew_nfs", "Yahni"),
    ("yahni", "tr"): ("food.stew_nfs", "stew_nfs", "Yahni"),
    ("crab_salad", "en"): ("food.crab_salad", "crab_salad", "Yengeç salatası"),
    ("yengec_salatasi", "tr"): ("food.crab_salad", "crab_salad", "Yengeç salatası"),
    ("salmon_salad", "en"): ("food.salmon_salad", "salmon_salad", "Somon salatası"),
    ("somon_salatasi", "tr"): ("food.salmon_salad", "salmon_salad", "Somon salatası"),
    ("tuna_salad", "en"): ("food.tuna_salad", "tuna_salad", "Ton balıklı salata"),
    ("ton_balikli_salata", "tr"): ("food.tuna_salad", "tuna_salad", "Ton balıklı salata"),
    ("soup_meatball", "en"): ("food.soup_meatball", "soup_meatball", "Köfteli çorba"),
    ("kofteli_corba", "tr"): ("food.soup_meatball", "soup_meatball", "Köfteli çorba"),
    ("broth", "en"): ("food.broth", "broth", "Et suyu"),
    ("et_suyu", "tr"): ("food.broth", "broth", "Et suyu"),
    ("soup_chicken", "en"): ("food.soup_chicken", "soup_chicken", "Tavuk çorbası"),
    ("soup_bisque", "en"): ("food.soup_bisque", "soup_bisque", "Kremalı deniz çorbası"),
    ("kremali_deniz_corbasi", "tr"): ("food.soup_bisque", "soup_bisque", "Kremalı deniz çorbası"),
    ("gravy", "en"): ("food.gravy", "gravy", "Et sosu"),
    ("et_sosu", "tr"): ("food.gravy", "gravy", "Et sosu"),
    ("soup_egg_drop", "en"): ("food.soup_egg_drop", "soup_egg_drop", "Yumurtalı çorba"),
    ("yumurtali_corba", "tr"): ("food.soup_egg_drop", "soup_egg_drop", "Yumurtalı çorba"),
    ("beans_nfs", "en"): ("food.beans_nfs", "beans_nfs", "Fasulye"),
    ("fasulye", "tr"): ("food.beans_nfs", "beans_nfs", "Fasulye"),
    ("bakla", "tr"): ("food.lima_beans", "lima_beans", "Bakla"),
    ("baked_beans", "en"): ("food.baked_beans", "baked_beans", "Fırın fasulye"),
    ("firin_fasulye", "tr"): ("food.baked_beans", "baked_beans", "Fırın fasulye"),
    ("refried_beans", "en"): ("food.refried_beans", "refried_beans", "Ezme fasulye"),
    ("ezme_fasulye", "tr"): ("food.refried_beans", "refried_beans", "Ezme fasulye"),
    ("pork_and_beans", "en"): ("food.pork_and_beans", "pork_and_beans", "Etli fasulye konservesi"),
    ("etli_fasulye_konservesi", "tr"): ("food.pork_and_beans", "pork_and_beans", "Etli fasulye konservesi"),
    ("split_peas_fat", "en"): ("food.split_peas_fat", "split_peas_fat", "Kuru bezelye"),
    ("wasabi_peas", "en"): ("food.wasabi_peas", "wasabi_peas", "Wasabi bezelye"),
    ("wasabi_bezelye", "tr"): ("food.wasabi_peas", "wasabi_peas", "Wasabi bezelye"),
    ("dal", "en"): ("food.dal", "dal", "Mercimek yemeği"),
    ("mercimek_yemegi", "tr"): ("food.dal", "dal", "Mercimek yemeği"),
    ("soy_nuts", "en"): ("food.soy_nuts", "soy_nuts", "Kavrulmuş soya"),
    ("kavrulmus_soya", "tr"): ("food.soy_nuts", "soy_nuts", "Kavrulmuş soya"),
    ("bean_soup", "en"): ("food.bean_soup", "bean_soup", "Fasulye çorbası"),
    ("fasulye_corbasi", "tr"): ("food.bean_soup", "bean_soup", "Fasulye çorbası"),
    ("nuts_nfs", "en"): ("food.nuts_nfs", "nuts_nfs", "Kuruyemiş"),
    ("kuruyemis", "tr"): ("food.nuts_nfs", "nuts_nfs", "Kuruyemiş"),
    ("brazil_nuts2", "en"): ("food.brazil_nuts2", "brazil_nuts2", "Brezilya cevizi"),
    ("brezilya_cevizi", "tr"): ("food.brazil_nuts2", "brazil_nuts2", "Brezilya cevizi"),
    ("chestnuts2", "en"): ("food.chestnuts2", "chestnuts2", "Kestane"),
    ("pecans", "en"): ("food.pecans", "pecans", "Pekan cevizi"),
    ("pekan_cevizi", "tr"): ("food.pecans", "pecans", "Pekan cevizi"),
    ("pine_nuts2", "en"): ("food.pine_nuts2", "pine_nuts2", "Çam fıstığı"),
    ("almond_butter2", "en"): ("food.almond_butter2", "almond_butter2", "Badem ezmesi"),
    ("badem_ezmesi", "tr"): ("food.almond_butter2", "almond_butter2", "Badem ezmesi"),
    ("almond_paste", "en"): ("food.almond_paste", "almond_paste", "Badem ezmesi"),
    ("cashew_butter", "en"): ("food.cashew_butter", "cashew_butter", "Kaju ezmesi"),
    ("kaju_ezmesi", "tr"): ("food.cashew_butter", "cashew_butter", "Kaju ezmesi"),
    ("soup_peanut", "en"): ("food.soup_peanut", "soup_peanut", "Yer fıstığı çorbası"),
    ("yer_fistigi_corbasi", "tr"): ("food.soup_peanut", "soup_peanut", "Yer fıstığı çorbası"),
    ("sesame_seeds", "en"): ("food.sesame_seeds", "sesame_seeds", "Susam"),
    ("susam", "tr"): ("food.sesame_seeds", "sesame_seeds", "Susam"),
    ("tahini2", "en"): ("food.tahini2", "tahini2", "Tahin"),
    ("flax_seeds2", "en"): ("food.flax_seeds2", "flax_seeds2", "Keten tohumu"),
    ("mixed_seeds", "en"): ("food.mixed_seeds", "mixed_seeds", "Karışık tohum"),
    ("karisik_tohum", "tr"): ("food.mixed_seeds", "mixed_seeds", "Karışık tohum"),
    ("chia_seeds2", "en"): ("food.chia_seeds2", "chia_seeds2", "Chia tohumu"),
    ("bread_cuban", "en"): ("food.bread_cuban", "bread_cuban", "Küba ekmeği"),
    ("kuba_ekmegi", "tr"): ("food.bread_cuban", "bread_cuban", "Küba ekmeği"),
    ("naan", "en"): ("food.naan", "naan", "Naan ekmeği"),
    ("naan_ekmegi", "tr"): ("food.naan", "naan", "Naan ekmeği"),
    ("pita_bread", "en"): ("food.pita_bread", "pita_bread", "Pide ekmeği"),
    ("pide_ekmegi", "tr"): ("food.pita_bread", "pita_bread", "Pide ekmeği"),
    ("bread_cheese", "en"): ("food.bread_cheese", "bread_cheese", "Peynirli ekmek"),
    ("peynirli_ekmek", "tr"): ("food.bread_cheese", "bread_cheese", "Peynirli ekmek"),
    ("bread_cinnamon", "en"): ("food.bread_cinnamon", "bread_cinnamon", "Tarçınlı ekmek"),
    ("tarcinli_ekmek", "tr"): ("food.bread_cinnamon", "bread_cinnamon", "Tarçınlı ekmek"),
    ("onion_bread", "en"): ("food.onion_bread", "onion_bread", "Soğanlı ekmek"),
    ("soganli_ekmek", "tr"): ("food.onion_bread", "onion_bread", "Soğanlı ekmek"),
    ("bread_potato", "en"): ("food.bread_potato", "bread_potato", "Patatesli ekmek"),
    ("patatesli_ekmek", "tr"): ("food.bread_potato", "bread_potato", "Patatesli ekmek"),
    ("bread_raisin", "en"): ("food.bread_raisin", "bread_raisin", "Üzümlü ekmek"),
    ("uzumlu_ekmek", "tr"): ("food.bread_raisin", "bread_raisin", "Üzümlü ekmek"),
    ("brioche", "en"): ("food.brioche", "brioche", "Brioche çöreği"),
    ("brioche_coregi", "tr"): ("food.brioche", "brioche", "Brioche çöreği"),
    ("croutons2", "en"): ("food.croutons2", "croutons2", "Kruton"),
    ("kruton", "tr"): ("food.croutons2", "croutons2", "Kruton"),
    ("melba_toast2", "en"): ("food.melba_toast2", "melba_toast2", "Melba tost"),
    ("melba_tost", "tr"): ("food.melba_toast2", "melba_toast2", "Melba tost"),
    ("zwieback", "en"): ("food.zwieback", "zwieback", "Zwieback peksimet"),
    ("zwieback_peksimet", "tr"): ("food.zwieback", "zwieback", "Zwieback peksimet"),
    ("bread_puri", "en"): ("food.bread_puri", "bread_puri", "Puri ekmeği"),
    ("puri_ekmegi", "tr"): ("food.bread_puri", "bread_puri", "Puri ekmeği"),
    ("bread_paratha", "en"): ("food.bread_paratha", "bread_paratha", "Paratha ekmeği"),
    ("paratha_ekmegi", "tr"): ("food.bread_paratha", "bread_paratha", "Paratha ekmeği"),
    ("black_bread", "en"): ("food.black_bread", "black_bread", "Siyah ekmek"),
    ("siyah_ekmek", "tr"): ("food.black_bread", "black_bread", "Siyah ekmek"),
    ("bread_oatmeal", "en"): ("food.bread_oatmeal", "bread_oatmeal", "Yulaflı ekmek"),
    ("yulafli_ekmek", "tr"): ("food.bread_oatmeal", "bread_oatmeal", "Yulaflı ekmek"),
    ("bread_oat_bran", "en"): ("food.bread_oat_bran", "bread_oat_bran", "Yulaf kepekli ekmek"),
    ("yulaf_kepekli_ekmek", "tr"): ("food.bread_oat_bran", "bread_oat_bran", "Yulaf kepekli ekmek"),
    ("bread_barley", "en"): ("food.bread_barley", "bread_barley", "Arpa ekmeği"),
    ("arpa_ekmegi", "tr"): ("food.bread_barley", "bread_barley", "Arpa ekmeği"),
    ("bread_soy", "en"): ("food.bread_soy", "bread_soy", "Soya ekmeği"),
    ("soya_ekmegi", "tr"): ("food.bread_soy", "bread_soy", "Soya ekmeği"),
    ("rice_bread", "en"): ("food.rice_bread", "rice_bread", "Pirinç unlu ekmek"),
    ("pirinc_unlu_ekmek", "tr"): ("food.rice_bread", "rice_bread", "Pirinç unlu ekmek"),
    ("biscuit", "en"): ("food.biscuit", "biscuit", "Bisküvi ekmeği"),
    ("biskuvi_ekmegi", "tr"): ("food.biscuit", "biscuit", "Bisküvi ekmeği"),
    ("scone", "en"): ("food.scone", "scone", "Çörek"),
    ("corek", "tr"): ("food.scone", "scone", "Çörek"),
    ("muffin", "en"): ("food.muffin", "muffin", "Muffin"),
    ("muffin", "tr"): ("food.muffin", "muffin", "Muffin"),
    ("bread_nut", "en"): ("food.bread_nut", "bread_nut", "Cevizli ekmek"),
    ("cevizli_ekmek", "tr"): ("food.bread_nut", "bread_nut", "Cevizli ekmek"),
    ("bread_pumpkin", "en"): ("food.bread_pumpkin", "bread_pumpkin", "Balkabaklı ekmek"),
    ("balkabakli_ekmek", "tr"): ("food.bread_pumpkin", "bread_pumpkin", "Balkabaklı ekmek"),
    ("bread_fruit", "en"): ("food.bread_fruit", "bread_fruit", "Meyveli ekmek"),
    ("meyveli_ekmek", "tr"): ("food.bread_fruit", "bread_fruit", "Meyveli ekmek"),
    ("cake_angel_food", "en"): ("food.cake_angel_food", "cake_angel_food", "Melek keki"),
    ("melek_keki", "tr"): ("food.cake_angel_food", "cake_angel_food", "Melek keki"),
    ("cake_cream", "en"): ("food.cake_cream", "cake_cream", "Kremalı pasta"),
    ("kremali_pasta", "tr"): ("food.cake_cream", "cake_cream", "Kremalı pasta"),
    ("cake_fruit", "en"): ("food.cake_fruit", "cake_fruit", "Meyveli kek"),
    ("meyveli_kek", "tr"): ("food.cake_fruit", "cake_fruit", "Meyveli kek"),
    ("cake_jelly_roll", "en"): ("food.cake_jelly_roll", "cake_jelly_roll", "Rulo pasta"),
    ("rulo_pasta", "tr"): ("food.cake_jelly_roll", "cake_jelly_roll", "Rulo pasta"),
    ("cake_sponge", "en"): ("food.cake_sponge", "cake_sponge", "Pandispanya"),
    ("pandispanya", "tr"): ("food.cake_sponge", "cake_sponge", "Pandispanya"),
    ("cake_torte", "en"): ("food.cake_torte", "cake_torte", "Torte pasta"),
    ("torte_pasta", "tr"): ("food.cake_torte", "cake_torte", "Torte pasta"),
    ("cookie_almond", "en"): ("food.cookie_almond", "cookie_almond", "Bademli kurabiye"),
    ("bademli_kurabiye", "tr"): ("food.cookie_almond", "cookie_almond", "Bademli kurabiye"),
    ("biscotti", "en"): ("food.biscotti", "biscotti", "Biscotti"),
    ("biscotti", "tr"): ("food.biscotti", "biscotti", "Biscotti"),
    ("coconut_cookie", "en"): ("food.coconut_cookie", "coconut_cookie", "Hindistan cevizli kurabiye"),
    ("hindistan_cevizli_kurabiye", "tr"): ("food.coconut_cookie", "coconut_cookie", "Hindistan cevizli kurabiye"),
    ("cookie_fig_bar", "en"): ("food.cookie_fig_bar", "cookie_fig_bar", "İncirli bar"),
    ("incirli_bar", "tr"): ("food.cookie_fig_bar", "cookie_fig_bar", "İncirli bar"),
    ("cookie_fortune", "en"): ("food.cookie_fortune", "cookie_fortune", "Fal kurabiyesi"),
    ("fal_kurabiyesi", "tr"): ("food.cookie_fortune", "cookie_fortune", "Fal kurabiyesi"),
    ("cookie_granola", "en"): ("food.cookie_granola", "cookie_granola", "Granola kurabiyesi"),
    ("granola_kurabiyesi", "tr"): ("food.cookie_granola", "cookie_granola", "Granola kurabiyesi"),
    ("macaroon", "en"): ("food.macaroon", "macaroon", "Makaron"),
    ("makaron", "tr"): ("food.macaroon", "macaroon", "Makaron"),
    ("meringue", "en"): ("food.meringue", "meringue", "Beze"),
    ("beze", "tr"): ("food.meringue", "meringue", "Beze"),
    ("cookie_molasses", "en"): ("food.cookie_molasses", "cookie_molasses", "Pekmezli kurabiye"),
    ("pekmezli_kurabiye", "tr"): ("food.cookie_molasses", "cookie_molasses", "Pekmezli kurabiye"),
    ("cookie_oatmeal", "en"): ("food.cookie_oatmeal", "cookie_oatmeal", "Yulaflı kurabiye"),
    ("yulafli_kurabiye", "tr"): ("food.cookie_oatmeal", "cookie_oatmeal", "Yulaflı kurabiye"),
    ("cookie_pumpkin", "en"): ("food.cookie_pumpkin", "cookie_pumpkin", "Balkabaklı kurabiye"),
    ("balkabakli_kurabiye", "tr"): ("food.cookie_pumpkin", "cookie_pumpkin", "Balkabaklı kurabiye"),
    ("raisin_cookie", "en"): ("food.raisin_cookie", "raisin_cookie", "Üzümlü kurabiye"),
    ("uzumlu_kurabiye", "tr"): ("food.raisin_cookie", "raisin_cookie", "Üzümlü kurabiye"),
    ("cookie_animal", "en"): ("food.cookie_animal", "cookie_animal", "Hayvan bisküvisi"),
    ("hayvan_biskuvisi", "tr"): ("food.cookie_animal", "cookie_animal", "Hayvan bisküvisi"),
    ("marie_biscuit", "en"): ("food.marie_biscuit", "marie_biscuit", "Marie bisküvi"),
    ("marie_biskuvi", "tr"): ("food.marie_biscuit", "marie_biscuit", "Marie bisküvi"),
    ("rugelach", "en"): ("food.rugelach", "rugelach", "Rugelach"),
    ("rugelach", "tr"): ("food.rugelach", "rugelach", "Rugelach"),
    ("apple_pie", "en"): ("food.apple_pie", "apple_pie", "Elmalı turta"),
    ("elmali_turta", "tr"): ("food.apple_pie", "apple_pie", "Elmalı turta"),
    ("pie_berry", "en"): ("food.pie_berry", "pie_berry", "Orman meyveli turta"),
    ("orman_meyveli_turta", "tr"): ("food.pie_berry", "pie_berry", "Orman meyveli turta"),
    ("pie_blueberry", "en"): ("food.pie_blueberry", "pie_blueberry", "Yaban mersinli turta"),
    ("yaban_mersinli_turta", "tr"): ("food.pie_blueberry", "pie_blueberry", "Yaban mersinli turta"),
    ("pie_cherry", "en"): ("food.pie_cherry", "pie_cherry", "Vişneli turta"),
    ("visneli_turta", "tr"): ("food.pie_cherry", "pie_cherry", "Vişneli turta"),
    ("lemon_pie", "en"): ("food.lemon_pie", "lemon_pie", "Limonlu turta"),
    ("limonlu_turta", "tr"): ("food.lemon_pie", "lemon_pie", "Limonlu turta"),
    ("pie_peach", "en"): ("food.pie_peach", "pie_peach", "Şeftalili turta"),
    ("seftalili_turta", "tr"): ("food.pie_peach", "pie_peach", "Şeftalili turta"),
    ("pie_strawberry", "en"): ("food.pie_strawberry", "pie_strawberry", "Çilekli turta"),
    ("cilekli_turta", "tr"): ("food.pie_strawberry", "pie_strawberry", "Çilekli turta"),
    ("pie_pumpkin", "en"): ("food.pie_pumpkin", "pie_pumpkin", "Balkabaklı turta"),
    ("balkabakli_turta", "tr"): ("food.pie_pumpkin", "pie_pumpkin", "Balkabaklı turta"),
    ("pie_pecan", "en"): ("food.pie_pecan", "pie_pecan", "Pekanlı turta"),
    ("pekanli_turta", "tr"): ("food.pie_pecan", "pie_pecan", "Pekanlı turta"),
    ("basbousa", "en"): ("food.basbousa", "basbousa", "Revani benzeri irmik tatlısı"),
    ("revani_benzeri_irmik_tatlisi", "tr"): ("food.basbousa", "basbousa", "Revani benzeri irmik tatlısı"),
    ("puff_pastry", "en"): ("food.puff_pastry", "puff_pastry", "Milföy hamuru"),
    ("milfoy_hamuru", "tr"): ("food.puff_pastry", "puff_pastry", "Milföy hamuru"),
    ("churros", "en"): ("food.churros", "churros", "Churros"),
    ("churros", "tr"): ("food.churros", "churros", "Churros"),
    ("beignet", "en"): ("food.beignet", "beignet", "Beignet hamur tatlısı"),
    ("beignet_hamur_tatlisi", "tr"): ("food.beignet", "beignet", "Beignet hamur tatlısı"),
    ("rice_cake2", "en"): ("food.rice_cake2", "rice_cake2", "Pirinç patlağı"),
    ("rice_crackers", "en"): ("food.rice_crackers", "rice_crackers", "Pirinç krakeri"),
    ("pirinc_krakeri", "tr"): ("food.rice_crackers", "rice_crackers", "Pirinç krakeri"),
    ("popcorn_cake", "en"): ("food.popcorn_cake", "popcorn_cake", "Mısır patlağı keki"),
    ("misir_patlagi_keki", "tr"): ("food.popcorn_cake", "popcorn_cake", "Mısır patlağı keki"),
    ("rice_paper", "en"): ("food.rice_paper", "rice_paper", "Pirinç yufkası"),
    ("pirinc_yufkasi", "tr"): ("food.rice_paper", "rice_paper", "Pirinç yufkası"),
    ("pita_chips2", "en"): ("food.pita_chips2", "pita_chips2", "Pide cipsi"),
    ("bagel_chips", "en"): ("food.bagel_chips", "bagel_chips", "Halka ekmek cipsi"),
    ("halka_ekmek_cipsi", "tr"): ("food.bagel_chips", "bagel_chips", "Halka ekmek cipsi"),
    ("cereal_cooked", "en"): ("food.cereal_cooked", "cereal_cooked", "Pişmiş tahıl lapası"),
    ("pismis_tahil_lapasi", "tr"): ("food.cereal_cooked", "cereal_cooked", "Pişmiş tahıl lapası"),
    ("barley2", "en"): ("food.barley2", "barley2", "Arpa"),
    ("millet2", "en"): ("food.millet2", "millet2", "Darı"),
    ("rice_cooked", "en"): ("food.rice_cooked", "rice_cooked", "Pirinç"),
    ("pirinc", "tr"): ("food.rice_cooked", "rice_cooked", "Pirinç"),
    ("rice_no_fat", "en"): ("food.rice_no_fat", "rice_no_fat", "Pilav"),
    ("brown_rice_no_fat", "en"): ("food.brown_rice_no_fat", "brown_rice_no_fat", "Esmer pirinç"),
    ("rice_with_milk", "en"): ("food.rice_with_milk", "rice_with_milk", "Sütlü pirinç"),
    ("sutlu_pirinc", "tr"): ("food.rice_with_milk", "rice_with_milk", "Sütlü pirinç"),
    ("congee", "en"): ("food.congee", "congee", "Pirinç lapası"),
    ("pirinc_lapasi", "tr"): ("food.congee", "congee", "Pirinç lapası"),
    ("glutinous_rice", "en"): ("food.glutinous_rice", "glutinous_rice", "Yapışkan pirinç"),
    ("yapiskan_pirinc", "tr"): ("food.glutinous_rice", "glutinous_rice", "Yapışkan pirinç"),
    ("couscous2", "en"): ("food.couscous2", "couscous2", "Kuskus"),
    ("cereal_corn_puffs", "en"): ("food.cereal_corn_puffs", "cereal_corn_puffs", "Mısır patlağı gevrek"),
    ("misir_patlagi_gevrek", "tr"): ("food.cereal_corn_puffs", "cereal_corn_puffs", "Mısır patlağı gevrek"),
    ("cereal_fruit_rings", "en"): ("food.cereal_fruit_rings", "cereal_fruit_rings", "Meyveli halka gevrek"),
    ("meyveli_halka_gevrek", "tr"): ("food.cereal_fruit_rings", "cereal_fruit_rings", "Meyveli halka gevrek"),
    ("cereal_granola", "en"): ("food.cereal_granola", "cereal_granola", "Granola"),
    ("granola", "tr"): ("food.cereal_granola", "cereal_granola", "Granola"),
    ("cereal_multigrain", "en"): ("food.cereal_multigrain", "cereal_multigrain", "Çok tahıllı gevrek"),
    ("cok_tahilli_gevrek", "tr"): ("food.cereal_multigrain", "cereal_multigrain", "Çok tahıllı gevrek"),
    ("cereal_oat_squares", "en"): ("food.cereal_oat_squares", "cereal_oat_squares", "Yulaf kare gevrek"),
    ("yulaf_kare_gevrek", "tr"): ("food.cereal_oat_squares", "cereal_oat_squares", "Yulaf kare gevrek"),
    ("cereal_os", "en"): ("food.cereal_os", "cereal_os", "Halka gevrek"),
    ("halka_gevrek", "tr"): ("food.cereal_os", "cereal_os", "Halka gevrek"),
    ("fried_rice_meatless", "en"): ("food.fried_rice_meatless", "fried_rice_meatless", "Kavrulmuş pilav"),
    ("kavrulmus_pilav", "tr"): ("food.fried_rice_meatless", "fried_rice_meatless", "Kavrulmuş pilav"),
    ("fried_rice", "en"): ("food.fried_rice", "fried_rice", "Kavrulmuş pilav"),
    ("fried_rice_chicken", "en"): ("food.fried_rice_chicken", "fried_rice_chicken", "Tavuklu kavrulmuş pilav"),
    ("tavuklu_kavrulmus_pilav", "tr"): ("food.fried_rice_chicken", "fried_rice_chicken", "Tavuklu kavrulmuş pilav"),
    ("soup_nfs", "en"): ("food.soup_nfs", "soup_nfs", "Çorba"),
    ("corba", "tr"): ("food.soup_nfs", "soup_nfs", "Çorba"),
    ("rice_soup", "en"): ("food.rice_soup", "rice_soup", "Pirinç çorbası"),
    ("pirinc_corbasi", "tr"): ("food.rice_soup", "rice_soup", "Pirinç çorbası"),
    ("barley_soup", "en"): ("food.barley_soup", "barley_soup", "Arpa çorbası"),
    ("arpa_corbasi", "tr"): ("food.barley_soup", "barley_soup", "Arpa çorbası"),
    ("soup_wonton", "en"): ("food.soup_wonton", "soup_wonton", "Mantı çorbası"),
    ("manti_corbasi", "tr"): ("food.soup_wonton", "soup_wonton", "Mantı çorbası"),
    ("dried_cranberries", "en"): ("food.dried_cranberries", "dried_cranberries", "Kuru kızılcık"),
    ("kuru_kizilcik", "tr"): ("food.dried_cranberries", "dried_cranberries", "Kuru kızılcık"),
    ("prunes", "en"): ("food.prunes", "prunes", "Kuru erik"),
    ("kuru_erik", "tr"): ("food.prunes", "prunes", "Kuru erik"),
    ("guava", "en"): ("food.guava", "guava", "Guava"),
    ("guava", "tr"): ("food.guava", "guava", "Guava"),
    ("lychee", "en"): ("food.lychee", "lychee", "Liçi"),
    ("lici", "tr"): ("food.lychee", "lychee", "Liçi"),
    ("mango", "en"): ("food.mango", "mango", "Mango"),
    ("mango", "tr"): ("food.mango", "mango", "Mango"),
    ("papaya", "en"): ("food.papaya", "papaya", "Papaya"),
    ("papaya", "tr"): ("food.papaya", "papaya", "Papaya"),
    ("rhubarb", "en"): ("food.rhubarb", "rhubarb", "Ravent"),
    ("ravent", "tr"): ("food.rhubarb", "rhubarb", "Ravent"),
    ("tamarind", "en"): ("food.tamarind", "tamarind", "Demirhindi"),
    ("demirhindi", "tr"): ("food.tamarind", "tamarind", "Demirhindi"),
    ("blackberries", "en"): ("food.blackberries", "blackberries", "Böğürtlen"),
    ("bogurtlen", "tr"): ("food.blackberries", "blackberries", "Böğürtlen"),
    ("strawberries_frozen", "en"): ("food.strawberries_frozen", "strawberries_frozen", "Çilek"),
    ("soup_fruit", "en"): ("food.soup_fruit", "soup_fruit", "Meyve çorbası"),
    ("meyve_corbasi", "tr"): ("food.soup_fruit", "soup_fruit", "Meyve çorbası"),
    ("apricot_nectar", "en"): ("food.apricot_nectar", "apricot_nectar", "Kayısı nektarı"),
    ("kayisi_nektari", "tr"): ("food.apricot_nectar", "apricot_nectar", "Kayısı nektarı"),
    ("mango_nectar", "en"): ("food.mango_nectar", "mango_nectar", "Mango nektarı"),
    ("mango_nektari", "tr"): ("food.mango_nectar", "mango_nectar", "Mango nektarı"),
    ("peach_nectar", "en"): ("food.peach_nectar", "peach_nectar", "Şeftali nektarı"),
    ("seftali_nektari", "tr"): ("food.peach_nectar", "peach_nectar", "Şeftali nektarı"),
    ("pear_nectar", "en"): ("food.pear_nectar", "pear_nectar", "Armut nektarı"),
    ("armut_nektari", "tr"): ("food.pear_nectar", "pear_nectar", "Armut nektarı"),
    ("potato_nfs", "en"): ("food.potato_nfs", "potato_nfs", "Patates"),
    ("potato_baked", "en"): ("food.potato_baked", "potato_baked", "Fırın patates"),
    ("firin_patates", "tr"): ("food.potato_baked", "potato_baked", "Fırın patates"),
    ("potato_roasted", "en"): ("food.potato_roasted", "potato_roasted", "Kızarmış fırın patates"),
    ("kizarmis_firin_patates", "tr"): ("food.potato_roasted", "potato_roasted", "Kızarmış fırın patates"),
    ("potato_chips_plain", "en"): ("food.potato_chips_plain", "potato_chips_plain", "Sade patates cipsi"),
    ("sade_patates_cipsi", "tr"): ("food.potato_chips_plain", "potato_chips_plain", "Sade patates cipsi"),
    ("potato_sticks", "en"): ("food.potato_sticks", "potato_sticks", "Patates çubuğu"),
    ("patates_cubugu", "tr"): ("food.potato_sticks", "potato_sticks", "Patates çubuğu"),
    ("potato_scalloped", "en"): ("food.potato_scalloped", "potato_scalloped", "Fırında dilim patates"),
    ("firinda_dilim_patates", "tr"): ("food.potato_scalloped", "potato_scalloped", "Fırında dilim patates"),
    ("potato_skins", "en"): ("food.potato_skins", "potato_skins", "Patates kabuğu"),
    ("patates_kabugu", "tr"): ("food.potato_skins", "potato_skins", "Patates kabuğu"),
    ("mashed_potato", "en"): ("food.mashed_potato", "mashed_potato", "Patates püresi"),
    ("patates_puresi", "tr"): ("food.mashed_potato", "mashed_potato", "Patates püresi"),
    ("potato_patty", "en"): ("food.potato_patty", "potato_patty", "Patates köftesi"),
    ("patates_koftesi", "tr"): ("food.potato_patty", "potato_patty", "Patates köftesi"),
    ("potato_tots", "en"): ("food.potato_tots", "potato_tots", "Patates topu"),
    ("patates_topu", "tr"): ("food.potato_tots", "potato_tots", "Patates topu"),
    ("potato_pancake", "en"): ("food.potato_pancake", "potato_pancake", "Patates mücveri"),
    ("patates_mucveri", "tr"): ("food.potato_pancake", "potato_pancake", "Patates mücveri"),
    ("soup_potato", "en"): ("food.soup_potato", "soup_potato", "Patates çorbası"),
    ("patates_corbasi", "tr"): ("food.soup_potato", "soup_potato", "Patates çorbası"),
    ("soup_pumpkin", "en"): ("food.soup_pumpkin", "soup_pumpkin", "Balkabağı çorbası"),
    ("balkabagi_corbasi", "tr"): ("food.soup_pumpkin", "soup_pumpkin", "Balkabağı çorbası"),
    ("sprouts", "en"): ("food.sprouts", "sprouts", "Filiz"),
    ("filiz", "tr"): ("food.sprouts", "sprouts", "Filiz"),
    ("asparagus", "en"): ("food.asparagus", "asparagus", "Kuşkonmaz"),
    ("kuskonmaz", "tr"): ("food.asparagus", "asparagus", "Kuşkonmaz"),
    ("brussels_sprouts", "en"): ("food.brussels_sprouts", "brussels_sprouts", "Brüksel lahanası"),
    ("bruksel_lahanasi", "tr"): ("food.brussels_sprouts", "brussels_sprouts", "Brüksel lahanası"),
    ("cactus", "en"): ("food.cactus", "cactus", "Kaktüs yaprağı"),
    ("kaktus_yapragi", "tr"): ("food.cactus", "cactus", "Kaktüs yaprağı"),
    ("jicama", "en"): ("food.jicama", "jicama", "Yer elması"),
    ("yer_elmasi", "tr"): ("food.jicama", "jicama", "Yer elması"),
    ("kohlrabi", "en"): ("food.kohlrabi", "kohlrabi", "Alabaş"),
    ("alabas", "tr"): ("food.kohlrabi", "kohlrabi", "Alabaş"),
    ("rutabaga", "en"): ("food.rutabaga", "rutabaga", "İsveç şalgamı"),
    ("isvec_salgami", "tr"): ("food.rutabaga", "rutabaga", "İsveç şalgamı"),
    ("seaweed", "en"): ("food.seaweed", "seaweed", "Deniz yosunu"),
    ("deniz_yosunu", "tr"): ("food.seaweed", "seaweed", "Deniz yosunu"),
    ("snowpeas", "en"): ("food.snowpeas", "snowpeas", "Şeker bezelye"),
    ("seker_bezelye", "tr"): ("food.snowpeas", "snowpeas", "Şeker bezelye"),
    ("turnip", "en"): ("food.turnip", "turnip", "Şalgam"),
    ("salgam", "tr"): ("food.turnip", "turnip", "Şalgam"),
    ("coleslaw", "en"): ("food.coleslaw", "coleslaw", "Lahana salatası"),
    ("lahana_salatasi", "tr"): ("food.coleslaw", "coleslaw", "Lahana salatası"),
    ("cabbage_salad", "en"): ("food.cabbage_salad", "cabbage_salad", "Beyaz lahana salatası"),
    ("beyaz_lahana_salatasi", "tr"): ("food.cabbage_salad", "cabbage_salad", "Beyaz lahana salatası"),
    ("leek", "en"): ("food.leek", "leek", "Pırasa"),
    ("pirasa", "tr"): ("food.leek", "leek", "Pırasa"),
    ("pea_salad", "en"): ("food.pea_salad", "pea_salad", "Bezelye salatası"),
    ("bezelye_salatasi", "tr"): ("food.pea_salad", "pea_salad", "Bezelye salatası"),
    ("soup_borscht", "en"): ("food.soup_borscht", "soup_borscht", "Pancar çorbası"),
    ("pancar_corbasi", "tr"): ("food.soup_borscht", "soup_borscht", "Pancar çorbası"),
    ("soup_gazpacho", "en"): ("food.soup_gazpacho", "soup_gazpacho", "Soğuk sebze çorbası"),
    ("soguk_sebze_corbasi", "tr"): ("food.soup_gazpacho", "soup_gazpacho", "Soğuk sebze çorbası"),
    ("soup_seaweed", "en"): ("food.soup_seaweed", "soup_seaweed", "Deniz yosunu çorbası"),
    ("deniz_yosunu_corbasi", "tr"): ("food.soup_seaweed", "soup_seaweed", "Deniz yosunu çorbası"),
    ("beef_soup", "en"): ("food.beef_soup", "beef_soup", "Et çorbası"),
    ("et_corbasi", "tr"): ("food.beef_soup", "beef_soup", "Et çorbası"),
    ("sauce_nfs", "en"): ("food.sauce_nfs", "sauce_nfs", "Sos"),
    ("sos", "tr"): ("food.sauce_nfs", "sauce_nfs", "Sos"),
    ("coconut_oil", "en"): ("food.coconut_oil", "coconut_oil", "Hindistan cevizi yağı"),
    ("hindistan_cevizi_yagi", "tr"): ("food.coconut_oil", "coconut_oil", "Hindistan cevizi yağı"),
    ("peanut_oil", "en"): ("food.peanut_oil", "peanut_oil", "Yer fıstığı yağı"),
    ("yer_fistigi_yagi", "tr"): ("food.peanut_oil", "peanut_oil", "Yer fıstığı yağı"),
    ("canola_oil", "en"): ("food.canola_oil", "canola_oil", "Kanola yağı"),
    ("kanola_yagi", "tr"): ("food.canola_oil", "canola_oil", "Kanola yağı"),
    ("sesame_oil", "en"): ("food.sesame_oil", "sesame_oil", "Susam yağı"),
    ("susam_yagi", "tr"): ("food.sesame_oil", "sesame_oil", "Susam yağı"),
    ("soybean_oil", "en"): ("food.soybean_oil", "soybean_oil", "Soya yağı"),
    ("soya_yagi", "tr"): ("food.soybean_oil", "soybean_oil", "Soya yağı"),
    ("walnut_oil", "en"): ("food.walnut_oil", "walnut_oil", "Ceviz yağı"),
    ("ceviz_yagi", "tr"): ("food.walnut_oil", "walnut_oil", "Ceviz yağı"),
    ("salad_dressing", "en"): ("food.salad_dressing", "salad_dressing", "Salata sosu"),
    ("salata_sosu", "tr"): ("food.salad_dressing", "salad_dressing", "Salata sosu"),
    ("salad_dressing_light", "en"): ("food.salad_dressing_light", "salad_dressing_light", "Hafif salata sosu"),
    ("hafif_salata_sosu", "tr"): ("food.salad_dressing_light", "salad_dressing_light", "Hafif salata sosu"),
    ("syrup", "en"): ("food.syrup", "syrup", "Şurup"),
    ("surup", "tr"): ("food.syrup", "syrup", "Şurup"),
    ("corn_syrup", "en"): ("food.corn_syrup", "corn_syrup", "Mısır şurubu"),
    ("misir_surubu", "tr"): ("food.corn_syrup", "corn_syrup", "Mısır şurubu"),
    ("simple_syrup", "en"): ("food.simple_syrup", "simple_syrup", "Şeker şurubu"),
    ("seker_surubu", "tr"): ("food.simple_syrup", "simple_syrup", "Şeker şurubu"),
    ("white_icing", "en"): ("food.white_icing", "white_icing", "Beyaz krema"),
    ("beyaz_krema", "tr"): ("food.white_icing", "white_icing", "Beyaz krema"),
    ("fruit_butter", "en"): ("food.fruit_butter", "fruit_butter", "Meyve ezmesi"),
    ("meyve_ezmesi", "tr"): ("food.fruit_butter", "fruit_butter", "Meyve ezmesi"),
    ("guava_paste", "en"): ("food.guava_paste", "guava_paste", "Guava ezmesi"),
    ("guava_ezmesi", "tr"): ("food.guava_paste", "guava_paste", "Guava ezmesi"),
    ("espresso", "en"): ("food.espresso", "espresso", "Espresso"),
    ("espresso", "tr"): ("food.espresso", "espresso", "Espresso"),
    ("latte", "en"): ("food.latte", "latte", "Latte"),
    ("latte", "tr"): ("food.latte", "latte", "Latte"),
    ("chicory", "en"): ("food.chicory", "chicory", "Hindiba içeceği"),
    ("hindiba_icecegi", "tr"): ("food.chicory", "chicory", "Hindiba içeceği"),
    ("tamarind_drink", "en"): ("food.tamarind_drink", "tamarind_drink", "Demirhindi şerbeti"),
    ("demirhindi_serbeti", "tr"): ("food.tamarind_drink", "tamarind_drink", "Demirhindi şerbeti"),
    ("milk_low_fat", "en"): ("food.milk_low_fat", "milk_low_fat", "Süt"),
    ("milk_skim", "en"): ("food.milk_skim", "milk_skim", "Süt"),
    ("soy_milk_sweet", "en"): ("food.soy_milk_sweet", "soy_milk_sweet", "Soya sütü"),
    ("soya_sutu", "tr"): ("food.soy_milk_sweet", "soy_milk_sweet", "Soya sütü"),
    ("soy_milk_plain", "en"): ("food.soy_milk_plain", "soy_milk_plain", "Soya sütü"),
    ("soy_milk_chocolate", "en"): ("food.soy_milk_chocolate", "soy_milk_chocolate", "Çikolatalı soya sütü"),
    ("cikolatali_soya_sutu", "tr"): ("food.soy_milk_chocolate", "soy_milk_chocolate", "Çikolatalı soya sütü"),
    ("almond_milk_sweet", "en"): ("food.almond_milk_sweet", "almond_milk_sweet", "Badem sütü"),
    ("badem_sutu", "tr"): ("food.almond_milk_sweet", "almond_milk_sweet", "Badem sütü"),
    ("almond_milk_plain", "en"): ("food.almond_milk_plain", "almond_milk_plain", "Badem sütü"),
    ("yogurt_parfait", "en"): ("food.yogurt_parfait", "yogurt_parfait", "Meyveli yoğurt parfe"),
    ("meyveli_yogurt_parfe", "tr"): ("food.yogurt_parfait", "yogurt_parfait", "Meyveli yoğurt parfe"),
    ("frozen_yogurt_vanilla", "en"): ("food.frozen_yogurt_vanilla", "frozen_yogurt_vanilla", "Donmuş yoğurt"),
    ("chocolate_milk", "en"): ("food.chocolate_milk", "chocolate_milk", "Çikolatalı süt"),
    ("cikolatali_sut", "tr"): ("food.chocolate_milk", "chocolate_milk", "Çikolatalı süt"),
    ("hot_chocolate", "en"): ("food.hot_chocolate", "hot_chocolate", "Sıcak çikolata"),
    ("sicak_cikolata", "tr"): ("food.hot_chocolate", "hot_chocolate", "Sıcak çikolata"),
    ("milk_shake_malt", "en"): ("food.milk_shake_malt", "milk_shake_malt", "Maltlı milkshake"),
    ("maltli_milkshake", "tr"): ("food.milk_shake_malt", "milk_shake_malt", "Maltlı milkshake"),
    ("fruit_smoothie", "en"): ("food.fruit_smoothie", "fruit_smoothie", "Meyve smoothie"),
    ("meyve_smoothie", "tr"): ("food.fruit_smoothie", "fruit_smoothie", "Meyve smoothie"),
    ("half_and_half", "en"): ("food.half_and_half", "half_and_half", "Yarım krema"),
    ("yarim_krema", "tr"): ("food.half_and_half", "half_and_half", "Yarım krema"),
    ("coffee_creamer", "en"): ("food.coffee_creamer", "coffee_creamer", "Kahve kreması"),
    ("kahve_kremasi", "tr"): ("food.coffee_creamer", "coffee_creamer", "Kahve kreması"),
    ("sour_cream_fat_free", "en"): ("food.sour_cream_fat_free", "sour_cream_fat_free", "Ekşi krema"),
    ("ranch_dip", "en"): ("food.ranch_dip", "ranch_dip", "Ranch sos"),
    ("ranch_sos", "tr"): ("food.ranch_dip", "ranch_dip", "Ranch sos"),
    ("spinach_dip", "en"): ("food.spinach_dip", "spinach_dip", "Ispanaklı sos"),
    ("ispanakli_sos", "tr"): ("food.spinach_dip", "spinach_dip", "Ispanaklı sos"),
    ("vegetable_dip", "en"): ("food.vegetable_dip", "vegetable_dip", "Sebzeli sos"),
    ("sebzeli_sos", "tr"): ("food.vegetable_dip", "vegetable_dip", "Sebzeli sos"),
    ("ice_cream_vanilla", "en"): ("food.ice_cream_vanilla", "ice_cream_vanilla", "Dondurma"),
    ("ice_cream_chocolate", "en"): ("food.ice_cream_chocolate", "ice_cream_chocolate", "Dondurma"),
    ("ice_cream_cone", "en"): ("food.ice_cream_cone", "ice_cream_cone", "Külahta dondurma"),
    ("kulahta_dondurma", "tr"): ("food.ice_cream_cone", "ice_cream_cone", "Külahta dondurma"),
    ("ice_cream_sundae", "en"): ("food.ice_cream_sundae", "ice_cream_sundae", "Dondurmalı sundae"),
    ("dondurmali_sundae", "tr"): ("food.ice_cream_sundae", "ice_cream_sundae", "Dondurmalı sundae"),
    ("light_ice_cream", "en"): ("food.light_ice_cream", "light_ice_cream", "Hafif dondurma"),
    ("hafif_dondurma", "tr"): ("food.light_ice_cream", "light_ice_cream", "Hafif dondurma"),
    ("lima_beans", "en"): ("food.lima_beans", "lima_beans", "Bakla"),
    ("brazil_nuts", "en"): ("food.brazil_nuts", "brazil_nuts", "Brezilya cevizi"),
    ("almond_butter", "en"): ("food.almond_butter", "almond_butter", "Badem ezmesi"),
    ("croutons", "en"): ("food.croutons", "croutons", "Kruton"),
    ("melba_toast", "en"): ("food.melba_toast", "melba_toast", "Melba tost"),
    ("marmalade", "en"): ("food.marmalade", "marmalade", "Marmelat"),
    ("marmelat", "tr"): ("food.marmalade", "marmalade", "Marmelat"),
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
