from __future__ import annotations

import argparse
import hashlib
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


API = "https://commons.wikimedia.org/w/api.php"
ALLOWED_LICENSE_MARKERS = ("cc0", "public domain", "cc by", "cc-by")
REJECTED_LICENSE_MARKERS = ("-nc", "noncommercial", "fair use", "copyrighted")
USER_AGENT = "NutriSenseResearch/1.0 (TUBITAK 2209 project; dataset curation)"

TARGETS = {
    "pirinc_pilavi": [
        "Turkish rice pilaf food",
        "pilav Turkish cuisine",
        "rice pilaf close up food",
        "Turkish pilaf rice bowl",
    ],
    "patlamis_misir": [
        "popcorn food bowl",
        "popped popcorn bowl snack",
        "plain popcorn close up",
    ],
    "lahmacun": ["lahmacun Turkish food"],
    "kebap": [
        "Turkish kebab mixed grill plate",
        "Turkish kebab meat plate restaurant",
        "ızgara kebap Turkish food",
    ],
    "adana_kebap": [
        "Adana kebab plate Turkish food",
        "Adana kebabı skewer plate",
    ],
    "patlican_kebabi": [
        "patlıcan kebabı Turkish food",
        "eggplant kebab Turkish cuisine plate",
    ],
    "tas_kebabi": [
        "tas kebabi Turkish stew",
        "tas kebabı Turkish food bowl",
    ],
    "elma": [
        "red apple whole fruit isolated",
        "red apples fruit bowl",
        "green apple whole fruit",
        "apple fruit market close up",
    ],
    "seftali": [
        "peach fruit food",
        "fresh whole peaches fruit close up",
        "ripe peaches market fruit",
    ],
    "kayisi": [
        "apricot fruit food",
        "fresh whole apricots fruit close up",
        "ripe apricots market fruit",
    ],
    "muz": ["banana fruit food"],
    "misir": ["corn on the cob food"],
    "levrek": [
        "European sea bass cooked whole plate",
        "grilled sea bass Turkish food",
        "levrek fish plate",
    ],
    "cipura": [
        "grilled sea bream whole plate",
        "çipura fish Turkish food",
        "gilthead sea bream cooked",
    ],
    "somon": [
        "cooked salmon fillet plate",
        "grilled salmon fillet food",
    ],
}


def _get_json(params: dict[str, str | int]) -> dict:
    url = f"{API}?{urllib.parse.urlencode(params)}"
    for attempt in range(6):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            if exc.code != 429 or attempt == 5:
                raise
            retry_after = exc.headers.get("Retry-After")
            delay = float(retry_after) if retry_after else min(60.0, 5.0 * (2**attempt))
            time.sleep(delay)
        except (TimeoutError, urllib.error.URLError):
            if attempt == 5:
                raise
            time.sleep(min(30.0, 2.0 * (2**attempt)))
    raise RuntimeError("Wikimedia API request exhausted retries")


def _plain(metadata: dict, key: str) -> str:
    value = metadata.get(key, {}).get("value", "")
    return str(value).replace("\n", " ").strip()


def _license_allowed(short_name: str, license_url: str) -> bool:
    normalized = f"{short_name} {license_url}".lower()
    return (
        any(marker in normalized for marker in ALLOWED_LICENSE_MARKERS)
        and not any(marker in normalized for marker in REJECTED_LICENSE_MARKERS)
    )


def _search(query: str, limit: int) -> list[dict]:
    payload = _get_json(
        {
            "action": "query",
            "format": "json",
            "generator": "search",
            "gsrsearch": query,
            "gsrnamespace": 6,
            "gsrlimit": min(limit, 50),
            "prop": "imageinfo",
            "iiprop": "url|mime|extmetadata|sha1",
            "iiurlwidth": 768,
        }
    )
    return list(payload.get("query", {}).get("pages", {}).values())


def acquire(output: Path, per_class: int, labels: list[str] | None = None) -> None:
    output.mkdir(parents=True, exist_ok=True)
    attribution_rows: list[dict] = []
    seen_hashes: set[str] = set()
    selected = labels or list(TARGETS)
    unknown = sorted(set(selected) - set(TARGETS))
    if unknown:
        raise ValueError(f"Unknown labels: {unknown}")
    for label in selected:
        queries = TARGETS[label]
        label_dir = output / label
        label_dir.mkdir(exist_ok=True)
        accepted = 0
        for query in queries:
            for page in _search(query, per_class * 3):
                if accepted >= per_class:
                    break
                info = (page.get("imageinfo") or [{}])[0]
                metadata = info.get("extmetadata") or {}
                mime = str(info.get("mime", ""))
                if mime not in {"image/jpeg", "image/png", "image/webp"}:
                    continue
                license_name = _plain(metadata, "LicenseShortName")
                license_url = _plain(metadata, "LicenseUrl")
                if not _license_allowed(license_name, license_url):
                    continue
                download_url = info.get("thumburl") or info.get("url")
                if not download_url:
                    continue
                request = urllib.request.Request(
                    download_url, headers={"User-Agent": USER_AGENT}
                )
                try:
                    with urllib.request.urlopen(request, timeout=45) as response:
                        data = response.read(12 * 1024 * 1024)
                except (OSError, TimeoutError):
                    continue
                digest = hashlib.sha256(data).hexdigest()
                if digest in seen_hashes:
                    continue
                seen_hashes.add(digest)
                suffix = ".png" if mime == "image/png" else ".jpg"
                path = label_dir / f"{digest[:16]}{suffix}"
                path.write_bytes(data)
                attribution_rows.append(
                    {
                        "label": label,
                        "local_path": path.relative_to(output).as_posix(),
                        "sha256": digest,
                        "title": page.get("title", ""),
                        "description_url": info.get("descriptionurl", ""),
                        "download_url": download_url,
                        "license": license_name,
                        "license_url": license_url,
                        "artist": _plain(metadata, "Artist"),
                        "credit": _plain(metadata, "Credit"),
                        "source": _plain(metadata, "Source"),
                        "query": query,
                        "review_status": "pending_visual_review",
                    }
                )
                accepted += 1
                time.sleep(0.15)
            if accepted >= per_class:
                break
        print(f"{label}: {accepted}/{per_class}")
    (output / "attribution.json").write_text(
        json.dumps(attribution_rows, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Acquire review-only, openly licensed food image candidates."
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--per-class", type=int, default=20)
    parser.add_argument(
        "--config",
        type=Path,
        help="Load every class from a NutriSense JSON config and generate search queries for missing targets.",
    )
    parser.add_argument(
        "--labels",
        nargs="+",
        help="Acquire only these labels; with --config, defaults to every class in the config.",
    )
    args = parser.parse_args()
    selected = args.labels
    if args.config:
        config = json.loads(args.config.read_text(encoding="utf-8"))
        configured_labels: list[str] = []
        for item in config.get("classes", []):
            label = str(item["id"])
            turkish_name = str(item.get("tr") or label.replace("_", " "))
            configured_labels.append(label)
            if label not in TARGETS:
                englishish_name = label.replace("_", " ")
                TARGETS[label] = [
                    f'"{turkish_name}" Turkish food',
                    f'"{turkish_name}" food plate',
                    f'"{englishish_name}" food',
                    f'"{turkish_name}" ev yapımı yemek',
                    f'"{turkish_name}" restoran tabağı',
                    f'"{englishish_name}" homemade food',
                    f'"{englishish_name}" restaurant plate',
                    f'"{englishish_name}" close up food',
                    f'"{englishish_name}" top view food',
                ]
            else:
                englishish_name = label.replace("_", " ")
                extra_queries = [
                    f'"{turkish_name}" ev yapımı yemek',
                    f'"{turkish_name}" restoran tabağı',
                    f'"{englishish_name}" homemade food',
                    f'"{englishish_name}" restaurant plate',
                    f'"{englishish_name}" close up food',
                    f'"{englishish_name}" top view food',
                ]
                TARGETS[label].extend(
                    query for query in extra_queries if query not in TARGETS[label]
                )
        selected = selected or configured_labels
    acquire(args.output, args.per_class, selected)


if __name__ == "__main__":
    main()
