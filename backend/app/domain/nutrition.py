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
