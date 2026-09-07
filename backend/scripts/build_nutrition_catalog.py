"""Rebuild the reviewed FNDDS subset from the official, pinned USDA archive.

Usage: python scripts/build_nutrition_catalog.py --archive /path/fndds.zip
No network, API key, participant data, or database access is required.
"""

import argparse
import hashlib
import json
from pathlib import Path
import zipfile


ARCHIVE_SHA256 = "dfb06ae7ddc397ccd570b91c14b75438ab2ba39f64f22d321f61d4a52a77f3eb"
SOURCE_URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_json_2024-10-31.zip"
# Hacim olcusunun mililitre karsiligi. Yogunluk, FNDDS porsiyonunun gram
# agirligi bu hacme bolunerek bulunur; sabit "1 ml = 1 g" varsayilmaz.
MILLILITRES = {
    "1 fl oz": 29.5735,
    "1 fl oz (NFS)": 29.5735,
    "1 fl oz (no ice)": 29.5735,
    "1 cup": 236.588,
}
# Katilarda "1 cup" bir hacim olcusudur ama yogunluk degildir: bir su bardagi
# ekmek 40 gramdir. Bu yuzden ml birimi yalnizca burada icecek olarak
# isaretlenen kayitlara verilir; heuristik ile turetilmez.
REVIEWED = {
    # ── İçecekler ───────────────────────────────────────────────────
    2710488: (
        "tea", "Tea, hot, leaf, black",
        "Çay (siyah, demleme)", (("ml", "1 fl oz"),),
    ),
    2710490: (
        "green_tea", "Tea, hot, leaf, green",
        "Yeşil çay", (("ml", "1 fl oz"),),
    ),
    2710377: (
        "turkish_coffee", "Coffee, Turkish",
        "Türk kahvesi", (("ml", "1 fl oz"),),
    ),
    2710375: (
        "brewed_coffee", "Coffee, brewed",
        "Filtre kahve", (("ml", "1 fl oz"),),
    ),
    2705385: (
        "milk", "Milk, whole",
        "Süt (tam yağlı)", (("ml", "1 fl oz"),),
    ),
    2705386: (
        "milk_reduced_fat", "Milk, reduced fat (2%)",
        "Süt (yarım yağlı)", (("ml", "1 fl oz"),),
    ),
    2709186: (
        "orange_juice", "Orange juice, 100%, NFS",
        "Portakal suyu (%100)", (("ml", "1 fl oz (no ice)"),),
    ),
    2709320: (
        "apple_juice", "Apple juice, 100%",
        "Elma suyu (%100)", (("ml", "1 fl oz (no ice)"),),
    ),
    2710570: (
        "lemonade", "Lemonade, fruit juice drink",
        "Limonata", (("ml", "1 fl oz (no ice)"),),
    ),
    2710541: (
        "cola", "Soft drink, cola",
        "Kola (gazlı içecek)", (("ml", "1 fl oz (no ice)"),),
    ),
    # ── Süt ürünleri ────────────────────────────────────────────────
    2705418: (
        "yogurt", "Yogurt, whole milk, plain",
        "Yoğurt (tam yağlı, sade)", (("kase", "1 cup"),),
    ),
    2705714: (
        "feta_cheese", "Cheese, Feta",
        "Beyaz peynir (feta)", (("dilim", "1 wedge (1.33 oz)"),),
    ),
    2705709: (
        "cheddar_cheese", "Cheese, Cheddar",
        "Kaşar benzeri peynir (cheddar)", (("dilim", "1 slice"),),
    ),
    2705747: (
        "cottage_cheese", "Cheese, cottage, NFS",
        "Lor peyniri (cottage)", (("kase", "1 cup"),),
    ),
    2710154: (
        "butter", "Butter, NFS",
        "Tereyağı", (),
    ),
    2705629: (
        "ice_cream", "Ice cream, NFS",
        "Dondurma", (("kase", "1 cup"),),
    ),
    # ── Ekmek ve unlu mamul ─────────────────────────────────────────
    2707598: (
        "bread", "Bread, white",
        "Ekmek (beyaz)", (("dilim", "1 medium or regular slice"),),
    ),
    2707709: (
        "whole_wheat_bread", "Bread, whole wheat",
        "Tam buğday ekmeği", (("dilim", "1 medium or regular slice"),),
    ),
    2707684: (
        "bagel", "Bagel",
        "Halka ekmek (bagel)", (("adet", "1 regular"),),
    ),
    2708726: (
        "cheese_pastry", "Pastry, cheese-filled",
        "Peynirli börek benzeri hamur işi", (("adet", "1 pastry"),),
    ),
    2708044: (
        "baklava", "Baklava",
        "Baklava (genel tarif)", (("adet", "1 piece"),),
    ),
    # ── Tahıl ve bakliyat ───────────────────────────────────────────
    2708403: (
        "rice", "Rice, white, cooked, NS as to fat",
        "Pilav (beyaz pirinç)", (("kase", "1 cup, cooked"),),
    ),
    2708409: (
        "brown_rice", "Rice, brown, cooked, NS as to fat",
        "Esmer pirinç pilavı", (("kase", "1 cup, cooked"),),
    ),
    2708357: (
        "pasta", "Pasta, cooked",
        "Makarna (haşlanmış)", (("kase", "1 cup, cooked"),),
    ),
    2708441: (
        "couscous", "Couscous, plain, cooked",
        "Kuskus (sade)", (("kase", "1 cup, cooked"),),
    ),
    2708438: (
        "bulgur", "Bulgur, no added fat",
        "Bulgur (yağ eklenmemiş)", (("kase", "1 cup, cooked"),),
    ),
    2707414: (
        "chickpeas", "Chickpeas, NFS",
        "Nohut", (("kase", "1 cup"),),
    ),
    2707353: (
        "white_beans", "White beans, NFS",
        "Kuru fasulye (beyaz)", (("kase", "1 cup"),),
    ),
    2707425: (
        "lentils", "Lentils, from dried, no added fat",
        "Mercimek (kuru, yağsız)", (("kase", "1 cup"),),
    ),
    2707402: (
        "hummus", "Hummus, plain",
        "Humus (sade)", (("kase", "1 individual container"),),
    ),
    # ── Et, tavuk, balık ────────────────────────────────────────────
    2705956: (
        "chicken_breast", "Chicken breast, baked, broiled, or roasted, skin not eaten, from raw",
        "Tavuk göğsü (fırında, derisiz)", (("adet", "1 medium breast"),),
    ),
    2706037: (
        "chicken_thigh", "Chicken thigh, stewed, skin eaten",
        "Tavuk but (haşlama, derili)", (("adet", "1 medium thigh"),),
    ),
    2705854: (
        "ground_beef", "Beef, ground",
        "Dana kıyma", (),
    ),
    2706467: (
        "meatballs", "Meatballs, NS as to type of meat, with sauce",
        "Köfte (soslu, et türü belirtilmemiş)", (("adet", "1 meatball with sauce"),),
    ),
    2705905: (
        "lamb", "Lamb, NS as to cut",
        "Kuzu eti (kesim belirtilmemiş)", (("dilim", "1 piece/slice, any size"),),
    ),
    2707154: (
        "egg", "Egg, whole, boiled or poached",
        "Yumurta (haşlanmış)", (("adet", "1 egg"),),
    ),
    2707205: (
        "omelette", "Egg omelet or scrambled egg, no added fat",
        "Omlet (ilave yağsız)", (),
    ),
    2706224: (
        "fish", "Fish, NFS",
        "Balık (tür belirtilmemiş)", (),
    ),
    2706360: (
        "shrimp", "Shrimp, NFS",
        "Karides", (("adet", "1 small/medium shrimp"),),
    ),
    # ── Çorba ───────────────────────────────────────────────────────
    2707462: (
        "lentil_soup", "Soup, lentil",
        "Mercimek çorbası", (("kase", "1 cup"),),
    ),
    2710113: (
        "vegetable_soup", "Soup, vegetable",
        "Sebze çorbası", (("kase", "1 cup"),),
    ),
    2709149: (
        "chicken_noodle_soup", "Soup, chicken noodle",
        "Tavuklu şehriye çorbası", (("kase", "1 cup"),),
    ),
    2709757: (
        "tomato_soup", "Soup, tomato",
        "Domates çorbası", (("kase", "1 cup"),),
    ),
    # ── Sebze ───────────────────────────────────────────────────────
    2709719: (
        "tomato", "Tomatoes, raw",
        "Domates (çiğ)", (("adet", "1 whole"),),
    ),
    2709784: (
        "cucumber", "Cucumber, raw",
        "Salatalık (çiğ)", (("adet", "1 regular"),),
    ),
    2709785: (
        "eggplant", "Eggplant, raw",
        "Patlıcan (çiğ)", (("adet", "1 whole"),),
    ),
    2709800: (
        "green_pepper", "Peppers, sweet, green, raw",
        "Yeşil biber (çiğ)", (("adet", "1 regular"),),
    ),
    2709795: (
        "onion", "Onions, raw",
        "Soğan (çiğ)", (("adet", "1 whole"),),
    ),
    2709660: (
        "carrot", "Carrots, raw",
        "Havuç (çiğ)", (("adet", "1 regular carrot"),),
    ),
    2709789: (
        "lettuce", "Lettuce, raw",
        "Marul (çiğ)", (("kase", "1 cup"),),
    ),
    2709385: (
        "boiled_potato", "Potato, boiled, NFS",
        "Haşlanmış patates", (("adet", "1 medium"),),
    ),
    2709458: (
        "french_fries", "Potato, french fries, from fresh, fried",
        "Patates kızartması (taze patatesten)", (),
    ),
    2710089: (
        "green_olives", "Olives, green",
        "Yeşil zeytin", (("adet", "1 olive"),),
    ),
    # ── Meyve ───────────────────────────────────────────────────────
    2709215: (
        "apple", "Apple, raw",
        "Elma (çiğ)", (("adet", "1 medium"),),
    ),
    2709224: (
        "banana", "Banana, raw",
        "Muz (çiğ)", (("adet", "1 banana"),),
    ),
    2709171: (
        "orange", "Orange, raw",
        "Portakal (çiğ)", (("adet", "1 fruit"),),
    ),
    2709270: (
        "watermelon", "Watermelon, raw",
        "Karpuz (çiğ)", (("dilim", "1 medium wedge/slice"),),
    ),
    2709237: (
        "grapes", "Grapes, raw",
        "Üzüm (çiğ)", (("kase", "1 cup"),),
    ),
    2709283: (
        "strawberry", "Strawberries, raw",
        "Çilek (çiğ)", (("kase", "1 cup"),),
    ),
    2709231: (
        "cherry", "Cherries, raw",
        "Kiraz (çiğ)", (("kase", "1 cup"),),
    ),
    2709235: (
        "fig", "Fig, raw",
        "İncir (çiğ)", (("adet", "1 fig"),),
    ),
    2709221: (
        "apricot", "Apricot, raw",
        "Kayısı (çiğ)", (("adet", "1 apricot"),),
    ),
    2709212: (
        "raisins", "Raisins",
        "Kuru üzüm", (("kase", "1 cup"),),
    ),
    # ── Kuruyemiş ───────────────────────────────────────────────────
    2707531: (
        "walnuts", "Walnuts, excluding honey roasted",
        "Ceviz (bal kaplamasız)", (("adet", "1 nut"),),
    ),
    2707502: (
        "hazelnuts", "Hazelnuts",
        "Fındık", (("adet", "1 nut"),),
    ),
    2707485: (
        "almonds", "Almonds, NFS",
        "Badem", (("adet", "1 nut"),),
    ),
    2707527: (
        "pistachios", "Pistachio nuts, NFS",
        "Antep fıstığı", (("adet", "1 nut"),),
    ),
    # ── Katkı ve tatlı ──────────────────────────────────────────────
    2710186: (
        "olive_oil", "Olive oil",
        "Zeytinyağı", (),
    ),
    2710281: (
        "honey", "Honey",
        "Bal", (),
    ),
    2710301: (
        "jam", "Jam",
        "Reçel", (),
    ),
    # ── Hazır yemek ─────────────────────────────────────────────────
    2706920: (
        "hamburger", "Hamburger, NFS",
        "Hamburger (genel tarif)", (("adet", "1 hamburger"),),
    ),
    2708614: (
        "pizza", "Pizza, cheese, from restaurant or fast food, NS as to type of crust",
        "Pizza (peynirli, restoran tipi)", (("dilim", "1 piece, large pizza"),),
    ),
    # ── Model sınıfları ─────────────────────────────────────────────
    2709766: (
        "artichoke", "Artichoke",
        "Enginar", (("adet", "1 whole"),),
    ),
    2706232: (
        "anchovy", "Fish, anchovy",
        "Hamsi", (),
    ),
    2708404: (
        "rice_with_oil", "Rice, white, cooked, made with oil",
        "Pirinç pilavı (yağlı)", (("kase", "1 cup, cooked"),),
    ),
    2709073: (
        "stuffed_pepper", "Stuffed pepper, with rice and meat",
        "Biber dolması (pirinçli, etli)", (("kase", "1 cup"),),
    ),
    2709064: (
        "stuffed_grape_leaves", "Grape leaves stuffed with rice",
        "Yaprak sarma (pirinçli)", (("adet", "1 roll"),),
    ),
    2706730: (
        "shish_kebab", "Beef shish kabob with vegetables, excluding potatoes",
        "Şiş kebap (sebzeli, dana)", (("adet", "1 shishkabob"),),
    ),
    2710144: (
        "eggplant_meat_casserole", "Eggplant and meat casserole",
        "Patlıcanlı et yemeği (karnıyarık benzeri)", (("kase", "1 cup"),),
    ),
    2705849: (
        "beef_stew_meat", "Beef, stew meat",
        "Et sote için dana eti (haşlama)", (),
    ),
    2709131: (
        "tabbouleh", "Tabbouleh",
        "Kısır benzeri bulgur salatası (tabbouleh)", (("kase", "1 cup"),),
    ),
    2708708: (
        "steamed_dumpling", "Wonton, dumpling or pot sticker, steamed",
        "Buharda mantı benzeri hamur (etli)", (("adet", "1 item, any size"),),
    ),
    2710359: (
        "gummy_candy", "Candy, gummy",
        "Lokum benzeri jel şeker", (("adet", "1 piece"),),
    ),
    2710791: (
        "cooked_spinach", "Spinach, cooked, as ingredient",
        "Ispanak (pişmiş, sade)", (),
    ),
    2710803: (
        "cooked_green_beans", "Green beans, cooked, as ingredient",
        "Taze fasulye (pişmiş, sade)", (),
    ),
    2708024: (
        "fritter", "Fritter, plain",
        "Mücver benzeri kızartma (sade fritter)", (("adet", "1 fritter"),),
    ),
}
NUTRIENTS = {
    1008: ("calories_per_100g", "kcal"),
    1003: ("protein_per_100g", "g"),
    1005: ("carbs_per_100g", "g"),
    1004: ("fat_per_100g", "g"),
    1079: ("fiber_per_100g", "g"),
}


# -- Piyasa ortalamasi tahminleri ----------------------------------------
#
# USDA arsivinde karsiligi olmayan Turk yemekleri. Degerler laboratuvar
# olcumu degildir; herkese acik Turkce kalori kaynaklarinin yayimladigi
# degerlerden secilmistir. Her kayit ESTIMATED olarak isaretlenir, kendi
# kaynak listesini tasir ve dogrulanmis kayitlardan ayri gorunur.
#
# Secim olcutu makro capraz kontroludur: protein*4 + karbonhidrat*4 +
# yag*9 ile bildirilen kalori arasindaki fark yuzde onu asarsa kaynak
# elenir. Boyle kaynaklar genellikle porsiyon degerini 100 gram diye
# yaziyor; ornegin bir gozleme kaydi 100 gramda 103 gram karbonhidrat
# bildiriyordu.
ESTIMATE_LICENSE = (
    "Public secondary sources; published estimates, not a laboratory "
    "measurement"
)
ESTIMATE_RETRIEVED_AT = "2026-09-07T00:00:00Z"
ESTIMATED = {
    "lahmacun": {
        "display_name_tr": "Lahmacun (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/lahmacun",
            "https://www.besinanaliz.com/foods/lahmacun",
        ],
        "nutrients": {
            "calories_per_100g": 221, "protein_per_100g": 9.74,
            "carbs_per_100g": 32.27, "fat_per_100g": 5.55,
            "fiber_per_100g": 2.87,
        },
    },
    "manti": {
        "display_name_tr": "Manti (haslanmis, sossuz, tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/manti",
            "https://www.fitekran.com/besin-degeri/manti/",
        ],
        "nutrients": {
            "calories_per_100g": 170, "protein_per_100g": 4.12,
            "carbs_per_100g": 29.71, "fat_per_100g": 3.5,
            "fiber_per_100g": 0.85,
        },
    },
    "icli_kofte": {
        "display_name_tr": "Icli kofte (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/icli-kofte",
            "https://www.fitekran.com/besin-degeri/icli-kofte/",
        ],
        "nutrients": {
            "calories_per_100g": 233, "protein_per_100g": 9.87,
            "carbs_per_100g": 32.28, "fat_per_100g": 6.83,
            "fiber_per_100g": 2.4,
        },
    },
    "kisir": {
        "display_name_tr": "Kisir (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/kisir",
            "https://www.fitekran.com/besin-degeri/kisir/",
        ],
        "nutrients": {
            "calories_per_100g": 178, "protein_per_100g": 4.59,
            "carbs_per_100g": 31.69, "fat_per_100g": 3.75,
            "fiber_per_100g": 3.94,
        },
    },
    "kuru_fasulye": {
        "display_name_tr": "Kuru fasulye yemegi (tahmini)",
        "sources": [
            "https://yemek.com/kuru-fasulye-kalori/",
            "https://www.diyetkolik.com/kac-kalori/kuru-fasulye-etli",
        ],
        "nutrients": {
            "calories_per_100g": 140, "protein_per_100g": 7.0,
            "carbs_per_100g": 19.0, "fat_per_100g": 4.0,
            "fiber_per_100g": 6.0,
        },
    },
    "gozleme": {
        "display_name_tr": "Gozleme (peynirli, tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/gozleme",
            "https://www.fitekran.com/besin-degeri/gozleme/",
        ],
        "nutrients": {
            "calories_per_100g": 269, "protein_per_100g": 10.35,
            "carbs_per_100g": 46.1, "fat_per_100g": 6.83,
            "fiber_per_100g": 2.2,
        },
    },
    "mucver": {
        "display_name_tr": "Mucver (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/mucver",
            "https://www.fitekran.com/besin-degeri/mucver/",
        ],
        "nutrients": {
            "calories_per_100g": 145, "protein_per_100g": 6.43,
            "carbs_per_100g": 10.0, "fat_per_100g": 8.82,
            "fiber_per_100g": 2.13,
        },
    },
    "hunkar_begendi": {
        "display_name_tr": "Hunkar begendi (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/hunkar-begendi",
            "https://www.dytseydaertas.com/besin/hunkar-begendi",
        ],
        "nutrients": {
            "calories_per_100g": 174, "protein_per_100g": 10.04,
            "carbs_per_100g": 5.32, "fat_per_100g": 12.1,
            "fiber_per_100g": 1.08,
        },
    },
    "cig_kofte": {
        "display_name_tr": "Cig kofte (etsiz, tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/cig-kofte-etsiz",
            "https://www.fitekran.com/besin-degeri/cig-kofte-etsiz/",
        ],
        "nutrients": {
            "calories_per_100g": 181, "protein_per_100g": 4.62,
            "carbs_per_100g": 32.91, "fat_per_100g": 4.02,
            "fiber_per_100g": 4.28,
        },
    },
    "asure": {
        "display_name_tr": "Asure (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/asure",
            "https://www.nefisyemektarifleri.com/kac-kalori/asure/",
        ],
        "nutrients": {
            "calories_per_100g": 344, "protein_per_100g": 7.84,
            "carbs_per_100g": 61.21, "fat_per_100g": 5.56,
            "fiber_per_100g": 6.82,
        },
    },
    "simit": {
        "display_name_tr": "Simit (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/susamli-simit",
            "https://www.fitekran.com/besin-degeri/sokak-simiti/",
        ],
        "nutrients": {
            "calories_per_100g": 320, "protein_per_100g": 9.0,
            "carbs_per_100g": 62.0, "fat_per_100g": 4.0,
            "fiber_per_100g": 2.5,
        },
    },
    "lokum": {
        "display_name_tr": "Lokum (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/lokum",
            "https://www.dytseydaertas.com/besin/lokum",
        ],
        "nutrients": {
            "calories_per_100g": 359, "protein_per_100g": 0.12,
            "carbs_per_100g": 89.28, "fat_per_100g": 0.19,
            "fiber_per_100g": 0.5,
        },
    },
}


def _macro_delta_percent(nutrients: dict) -> float:
    macro = (
        nutrients["protein_per_100g"] * 4
        + nutrients["carbs_per_100g"] * 4
        + nutrients["fat_per_100g"] * 9
    )
    calories = nutrients["calories_per_100g"]
    return abs(macro - calories) / calories * 100


def _add_estimates(catalog: dict) -> None:
    """Add estimated Turkish dishes, each carrying the sources used."""
    for key, row in ESTIMATED.items():
        delta = _macro_delta_percent(row["nutrients"])
        if delta > 10:
            raise ValueError(
                f"{key}: macro cross-check failed ({delta:.1f}%)"
            )
        source_id = f"estimate:{key}"
        catalog["_meta"]["source_inventory"][source_id] = {
            "source_url": row["sources"][0],
            "source_item_name": row["display_name_tr"],
            "retrieved_at": ESTIMATE_RETRIEVED_AT,
            "license": ESTIMATE_LICENSE,
            "attribution": (
                "Piyasa ortalamasi tahmini. Kaynaklar: "
                + ", ".join(row["sources"])
            ),
        }
        record = {
            "evidence_status": "ESTIMATED",
            "source_item_id": source_id,
            "locale": "tr-TR",
            "display_name_tr": row["display_name_tr"],
            "default_portion_g": 100,
            "serving_unit": "gram",
            "serving_quantity": 100,
            "portion_units": [],
            "estimate_sources": row["sources"],
            "macro_delta_percent": round(delta, 2),
        }
        record.update(row["nutrients"])
        catalog[key] = record


def _portion_units(food: dict, specs, source_id: str) -> list:
    """Turn reviewed FNDDS portions into unit weights that carry their measure.

    Each row cites the exact portion row it came from. A food citation alone is
    not a weight measurement, so the catalog records the measure text too.
    """
    portions = {
        row["portionDescription"]: row["gramWeight"]
        for row in food.get("foodPortions", [])
        if row.get("portionDescription")
    }
    rows = []
    for unit, measure in specs:
        if measure not in portions:
            raise ValueError(
                f"Reviewed portion '{measure}' missing for {food['description']}"
            )
        grams = portions[measure]
        if not isinstance(grams, (int, float)) or grams <= 0:
            raise ValueError(f"Invalid gram weight for '{measure}'")
        if unit == "ml":
            millilitres = MILLILITRES[measure]
            value = grams / millilitres
            if not 0 < value <= 2:
                raise ValueError(f"Implausible density for {food['description']}")
        else:
            value = float(grams)
        rows.append({
            "unit": unit,
            "grams_per_unit": round(value, 4),
            "source_item_id": source_id,
            "source_measure": f"FNDDS food portion: {measure} = {grams} g",
        })
    return rows


def build_catalog(archive: Path) -> dict:
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("USDA archive checksum mismatch; review a new release explicitly")
    with zipfile.ZipFile(archive) as bundle:
        foods = json.loads(bundle.read("surveyDownload.json"))["SurveyFoods"]
    catalog = {"_meta": {
        "version": "usda-fndds-2021-2023-subset-v1",
        "evidence_status": "VERIFIED",
        "verification_method": "Exact nutrient extraction from pinned official USDA FNDDS archive",
        "archive_url": SOURCE_URL,
        "archive_sha256": ARCHIVE_SHA256,
        "expert_reviewed_at": None,
        "limitations": "Source verification is not clinical validation. Recipe and actual portion may differ.",
        "source_inventory": {},
    }}
    for food in foods:
        if food["fdcId"] not in REVIEWED:
            continue
        key, description, display, unit_specs = REVIEWED[food["fdcId"]]
        if food["description"] != description:
            raise ValueError("Reviewed food description changed")
        source_id = f"usda-fdc:{food['fdcId']}"
        url = f"https://fdc.nal.usda.gov/fdc-app.html#/food-details/{food['fdcId']}/nutrients"
        catalog["_meta"]["source_inventory"][source_id] = {
            "source_url": url, "source_item_name": description,
            "retrieved_at": "2026-09-07T05:37:48Z", "license": "CC0 1.0",
            "attribution": f"USDA FoodData Central, FNDDS 2021-2023. {description}. {url}",
        }
        record = {
            "evidence_status": "VERIFIED", "source_item_id": source_id,
            "locale": "en-US", "display_name_tr": display,
            # 100 g is a calculation basis, not a measured serving or a universal item weight.
            "default_portion_g": 100, "serving_unit": "gram", "serving_quantity": 100,
            "portion_units": _portion_units(food, unit_specs, source_id),
        }
        for nutrient in food["foodNutrients"]:
            spec = NUTRIENTS.get(nutrient["nutrient"]["id"])
            if spec:
                field, unit = spec
                if nutrient["nutrient"]["unitName"].lower() != unit:
                    raise ValueError("Unexpected nutrient unit")
                record[field] = nutrient["amount"]
        if not all(field in record for field, _ in NUTRIENTS.values()):
            raise ValueError("Missing required nutrient")
        catalog[key] = record
    if set(catalog) - {"_meta"} != {row[0] for row in REVIEWED.values()}:
        raise ValueError("Missing reviewed food")
    _add_estimates(catalog)
    return catalog


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "app/data/verified_nutrition.json")
    args = parser.parse_args()
    result = build_catalog(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(result) - 1} records (USDA verified + estimates): "
          f"{args.output}")
