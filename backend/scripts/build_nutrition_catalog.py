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
REVIEWED = {
    2708044: ("baklava", "Baklava", "Baklava (genel tarif)"),
    2706920: ("hamburger", "Hamburger, NFS", "Hamburger (genel tarif)"),
    2708614: (
        "pizza", "Pizza, cheese, from restaurant or fast food, NS as to type of crust",
        "Pizza (peynirli, restoran tipi)",
    ),
    2707205: (
        "omelette", "Egg omelet or scrambled egg, no added fat", "Omlet (ilave yağsız)",
    ),
    2709458: (
        "french_fries", "Potato, french fries, from fresh, fried", "Patates kızartması (taze patatesten)",
    ),
}
NUTRIENTS = {
    1008: ("calories_per_100g", "kcal"),
    1003: ("protein_per_100g", "g"),
    1005: ("carbs_per_100g", "g"),
    1004: ("fat_per_100g", "g"),
    1079: ("fiber_per_100g", "g"),
}


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
        key, description, display = REVIEWED[food["fdcId"]]
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
            "portion_units": [],
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
    return catalog


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "app/data/verified_nutrition.json")
    args = parser.parse_args()
    result = build_catalog(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(result) - 1} USDA records: {args.output}")
