# -*- coding: utf-8 -*-
"""Ham klasorlerden intake CSV uretir; kaynagi dosya adindan belirler."""

import csv
import io
import json
import os

RAW = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\data\raw"
CONFIG = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\configs\tr222_v1.json"
OUT = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\data\intake_tr222.csv"

config = json.load(io.open(CONFIG, encoding="utf-8"))
allowed = {c["id"] for c in config["classes"]} | {config["ood"]["label"]}


def source_of(filename):
    if filename.startswith("f101_"):
        return "food101_official", "food101_official"
    if filename.startswith("alp_"):
        return "alpsahin_turkish_food_combined", "alpsahin_turkish_food_combined"
    return "turkishfoods25", "turkishfoods25"


rows = 0
with io.open(OUT, "w", encoding="utf-8", newline="") as fh:
    writer = csv.writer(fh)
    writer.writerow(["path", "label", "source_id", "license_id", "group_id", "split_hint"])
    for label in sorted(os.listdir(RAW)):
        folder = os.path.join(RAW, label)
        if not os.path.isdir(folder) or label not in allowed:
            continue
        for name in sorted(os.listdir(folder)):
            if not name.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            source_id, license_id = source_of(name)
            writer.writerow([
                "%s/%s" % (label, name),
                label,
                source_id,
                license_id,
                "%s:%s" % (label, os.path.splitext(name)[0]),
                "",
            ])
            rows += 1
print("intake satiri:", rows)
