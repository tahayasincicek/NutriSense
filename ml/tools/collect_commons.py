"""Wikimedia Commons'tan açık lisanslı yemek fotoğrafı toplar.

Her görselin lisansı, yazarı ve kaynak sayfası ayrı ayrı kaydedilir; lisans
bilgisi okunamayan dosya indirilmez.

UYARI — 2 Eylül 2026'da ölçüldü: metin araması etiketleri ağır biçimde
kirletir. "simit" sorgusu tabelasında Simit Sarayı yazan sokak fotoğraflarını,
"lentil soup" sorgusu Türk mercimek çorbası olmayan mercimek yemeklerini
getirdi. Küratörlü kategoriler (Category:Simit vb.) temiz fakat sınıf başına
yalnız 14-61 öğe içeriyor; eğitim için gereken 300 hedefinin çok altında.

Bu betiğin çıktısı insan doğrulaması olmadan eğitime verilemez. Türk yemeği
sınıfları için doğru yol `docs/data_collection_protocol.md` altındaki kendi
çekim protokolüdür.

Eğitim ortamının parçası değildir; ayrı araç ortamında çalıştırılır.
"""

from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = (
    "NutriSense-Research/1.0 (TUBITAK 2209-A; academic dataset collection)"
)

# Kabul edilen lisanslar: eğitim ve türev çalışma serbest.
ALLOWED_LICENCE_PREFIXES = ("cc0", "cc-by", "cc by", "public domain", "pd-")

QUERIES: dict[str, list[str]] = {
    "simit": ["simit", "Turkish bagel simit", "susamlı simit"],
    "lahmacun": ["lahmacun", "Turkish pizza lahmacun"],
    "manti": ["manti Turkish dumpling", "Türk mantısı", "kayseri mantısı"],
    "mercimek_corbasi": [
        "mercimek çorbası",
        "Turkish lentil soup",
        "red lentil soup bowl",
    ],
    "menemen": ["menemen Turkish", "menemen dish egg tomato"],
}


def fetch(url: str) -> dict:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def search(term: str, limit: int) -> list[str]:
    url = (
        f"{API}?action=query&list=search&srsearch={quote(term)}%20filetype:bitmap"
        f"&srnamespace=6&srlimit={limit}&format=json"
    )
    try:
        payload = fetch(url)
    except Exception:  # noqa: BLE001 - ağ hatası tolere edilir
        return []
    return [item["title"] for item in payload.get("query", {}).get("search", [])]


def image_info(titles: list[str]) -> dict[str, dict]:
    if not titles:
        return {}
    joined = quote("|".join(titles))
    url = (
        f"{API}?action=query&titles={joined}&prop=imageinfo"
        "&iiprop=url|extmetadata|size&iiurlwidth=800&format=json"
    )
    try:
        payload = fetch(url)
    except Exception:  # noqa: BLE001
        return {}
    return payload.get("query", {}).get("pages", {})


def licence_of(metadata: dict) -> tuple[str, str, str] | None:
    extra = metadata.get("extmetadata", {})
    short = (extra.get("LicenseShortName", {}).get("value") or "").strip()
    if not short:
        return None
    normalised = short.lower()
    if not any(normalised.startswith(p) for p in ALLOWED_LICENCE_PREFIXES):
        return None
    author = (extra.get("Artist", {}).get("value") or "bilinmiyor").strip()
    # Artist alanı HTML içerebilir; kaba biçimde metne indirgenir.
    for tag in ("<", ">"):
        if tag in author:
            author = " ".join(
                part for part in author.replace("<", " <").split() if "<" not in part
            )
    return short, author[:200], (extra.get("Credit", {}).get("value") or "")[:120]


def collect(out_root: Path, per_class: int, records_path: Path) -> None:
    out_root.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, str]] = []

    for label, terms in QUERIES.items():
        kept = 0
        seen: set[str] = set()
        for term in terms:
            if kept >= per_class:
                break
            titles = search(term, 200)
            for chunk_start in range(0, len(titles), 20):
                if kept >= per_class:
                    break
                chunk = [t for t in titles[chunk_start:chunk_start + 20] if t not in seen]
                seen.update(chunk)
                for page in image_info(chunk).values():
                    if kept >= per_class:
                        break
                    infos = page.get("imageinfo") or []
                    if not infos:
                        continue
                    info = infos[0]
                    licence = licence_of(info)
                    if licence is None:
                        continue
                    source_url = info.get("thumburl") or info.get("url")
                    if not source_url:
                        continue
                    stem = Path(page["title"]).stem.replace(" ", "_")[:60]
                    stem = "".join(c for c in stem if c.isalnum() or c in "_-")
                    destination = out_root / label / f"{stem}.jpg"
                    if destination.exists():
                        continue
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    try:
                        request = Request(
                            source_url, headers={"User-Agent": USER_AGENT}
                        )
                        with urlopen(request, timeout=60) as response:
                            destination.write_bytes(response.read())
                    except Exception:  # noqa: BLE001
                        continue
                    short, author, credit = licence
                    records.append({
                        "path": f"{label}/{destination.name}",
                        "label": label,
                        "licence": short,
                        "author": author,
                        "credit": credit,
                        "commons_page": f"https://commons.wikimedia.org/wiki/{quote(page['title'])}",
                    })
                    kept += 1
                time.sleep(0.2)
        print(f"{label}: {kept}")

    records_path.parent.mkdir(parents=True, exist_ok=True)
    with records_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["path", "label", "licence", "author", "credit", "commons_page"],
        )
        writer.writeheader()
        writer.writerows(records)
    print(f"toplam {len(records)} kayit -> {records_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-root", type=Path, default=Path("data/commons_raw"))
    parser.add_argument("--per-class", type=int, default=300)
    parser.add_argument(
        "--records", type=Path, default=Path("data/commons_licences.csv")
    )
    args = parser.parse_args()
    collect(args.out_root, args.per_class, args.records)


if __name__ == "__main__":
    main()
