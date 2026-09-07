"""alpsahin parquet'lerini sinif klasorlerine acar.

Ayni yemegin iki etiket olmamasi icin MERGE haritasi uygulanir.
Kutu cizili 'labeled-img' degil, temiz 'raw-img' kullanilir.
"""

import json
import os
import re

import pyarrow.parquet as pq

D = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\data\downloads\alpsahin"
RAW = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\data\raw"

# Elimizdeki klasorle birebir ayni yemek olanlar.
MERGE = {
    "Baklava": "baklava",
    "Cig-Kofte": "cig_kofte",
    "Manti": "manti",
    "Lahmacun": "lahmacun",
    "Icli-Kofte": "icli_kofte",
    "Karniyarik": "karniyarik",
    "Kisir": "kisir",
    "Et-Sote": "et_sote",
    "Hunkar-Begendi": "hunkar_begendi",
    "Biber-Dolma": "biber_dolmasi",
    "Ispanak-Yemegi": "ispanak",
    "Yaprak-Sarma": "yaprak_sarma",
    "Kabak-Mucver": "mucver",
    "Hamsi-Tava": "hamsi",
    "Pilav": "pirinc_pilavi",
    "Canak-Enginar": "enginar",
    "Sulu-Kuru-Fasulye-Yemegi": "kuru_fasulye",
    "Omlet": "omelette",
    "Patates-Kizartmasi": "french_fries",
    "Dondurma": "ice_cream",
    "Pizza": "pizza",
    "Burger": "hamburger",
    "Cheesecake": "cheesecake",
    "Tiramisu": "tiramisu",
    "Pankek": "pancakes",
    "Waffle": "waffles",
    "Biftek": "steak",
    "Sosisli-Sandvic": "hot_dog",
}
# Turkce "Pasta" kek demek; Food-101'deki makarnayla karistirilmamali.
RENAME = {"Pasta": "yas_pasta"}


def slug(name):
    if name in MERGE:
        return MERGE[name]
    if name in RENAME:
        return RENAME[name]
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


shards = sorted(
    (f for f in os.listdir(D) if f.endswith(".parquet")),
    key=lambda f: int(f.split("-")[1].split(".")[0]),
)
counters = {}
written = 0
for shard in shards:
    pf = pq.ParquetFile(os.path.join(D, shard))
    for group in range(pf.num_row_groups):
        table = pf.read_row_group(group, columns=["raw-img", "class"])
        images = table.column("raw-img").to_pylist()
        labels = table.column("class").to_pylist()
        for img, label in zip(images, labels):
            name = slug(label)
            folder = os.path.join(RAW, name)
            if name not in counters:
                os.makedirs(folder, exist_ok=True)
                counters[name] = 0
            counters[name] += 1
            path = os.path.join(folder, "alp_%05d.jpg" % counters[name])
            with open(path, "wb") as fh:
                fh.write(img["bytes"])
            written += 1
    print("%s bitti - toplam %d" % (shard, written), flush=True)

print("YAZILAN %d gorsel, %d klasor" % (written, len(counters)))
out = os.path.join(os.path.dirname(D), "alpsahin_slugs.json")
with open(out, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(counters, fh, ensure_ascii=False, indent=2, sort_keys=True)
