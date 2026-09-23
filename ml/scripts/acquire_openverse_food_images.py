"""Download review-only food image candidates from Openverse.

Only CC0/Public Domain/CC BY/CC BY-SA results are accepted. Every downloaded
file keeps its source, creator and license metadata for later human review.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


API = "https://api.openverse.org/v1/images/"
USER_AGENT = "NutriSenseResearch/1.0 (TUBITAK 2209; open-license dataset curation)"
ALLOWED_LICENSES = {"cc0", "pdm", "by", "by-sa"}


def _request_json(params: dict[str, str | int]) -> dict:
    url = f"{API}?{urllib.parse.urlencode(params)}"
    for attempt in range(6):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            if exc.code != 429 or attempt == 5:
                raise
            retry_after = exc.headers.get("Retry-After")
            time.sleep(float(retry_after) if retry_after else min(90, 5 * 2**attempt))
        except (TimeoutError, urllib.error.URLError):
            if attempt == 5:
                raise
            time.sleep(min(45, 3 * 2**attempt))
    raise RuntimeError("Openverse request exhausted retries")


def _download(url: str) -> bytes | None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            content_type = response.headers.get_content_type()
            if content_type not in {"image/jpeg", "image/png", "image/webp"}:
                return None
            return response.read(12 * 1024 * 1024)
    except (OSError, TimeoutError, urllib.error.URLError):
        return None


def acquire(
    config_path: Path,
    output: Path,
    per_class: int,
    selected_labels: set[str] | None = None,
) -> None:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    configured_labels = {str(item["id"]) for item in config["classes"]}
    unknown_labels = (selected_labels or set()) - configured_labels
    if unknown_labels:
        raise ValueError(f"Unknown labels: {sorted(unknown_labels)}")
    output.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    seen: set[str] = set()

    for item in config["classes"]:
        label = str(item["id"])
        if selected_labels is not None and label not in selected_labels:
            continue
        turkish_name = str(item.get("tr") or label.replace("_", " "))
        queries = [
            f'"{turkish_name}" yemek',
            f'"{turkish_name}" Turkish food',
            f'"{label.replace("_", " ")}" food',
            f'"{turkish_name}" ev yapımı tabak',
            f'"{turkish_name}" restoran sunumu',
            f'"{turkish_name}" telefon fotoğrafı',
            f'"{label.replace("_", " ")}" homemade food plate',
            f'"{label.replace("_", " ")}" restaurant plate photo',
            f'"{label.replace("_", " ")}" close up food',
            f'"{label.replace("_", " ")}" top view food',
        ]
        label_dir = output / label
        label_dir.mkdir(exist_ok=True)
        accepted = 0
        for query in queries:
            if accepted >= per_class:
                break
            payload = _request_json(
                {
                    "q": query,
                    "license": ",".join(sorted(ALLOWED_LICENSES)),
                    "categories": "photograph",
                    "mature": "false",
                    # Anonymous Openverse clients are capped at 20 results/request.
                    "page_size": min(20, max(1, per_class)),
                }
            )
            for result in payload.get("results", []):
                if accepted >= per_class:
                    break
                license_name = str(result.get("license") or "").lower()
                if license_name not in ALLOWED_LICENSES:
                    continue
                image_url = result.get("thumbnail") or result.get("url")
                if not image_url:
                    continue
                data = _download(str(image_url))
                if not data:
                    continue
                digest = hashlib.sha256(data).hexdigest()
                if digest in seen:
                    continue
                seen.add(digest)
                path = label_dir / f"{digest[:16]}.jpg"
                path.write_bytes(data)
                rows.append(
                    {
                        "label": label,
                        "local_path": path.relative_to(output).as_posix(),
                        "sha256": digest,
                        "title": result.get("title") or "",
                        "creator": result.get("creator") or "",
                        "creator_url": result.get("creator_url") or "",
                        "source_url": result.get("foreign_landing_url") or "",
                        "download_url": image_url,
                        "license": license_name,
                        "license_version": result.get("license_version") or "",
                        "license_url": result.get("license_url") or "",
                        "provider": result.get("provider") or "",
                        "source": result.get("source") or "",
                        "query": query,
                        "review_status": "pending_visual_review",
                    }
                )
                accepted += 1
                time.sleep(0.1)
        print(f"{label}: {accepted}/{per_class}", flush=True)

    (output / "attribution.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Acquire open-license food candidates from Openverse")
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--per-class", type=int, default=20)
    parser.add_argument("--labels", nargs="+", help="Acquire only these configured labels")
    args = parser.parse_args()
    acquire(
        args.config,
        args.output,
        args.per_class,
        set(args.labels) if args.labels else None,
    )


if __name__ == "__main__":
    main()
