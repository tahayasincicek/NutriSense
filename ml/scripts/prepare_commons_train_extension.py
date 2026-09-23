"""Append reviewed Commons images to the training split without test leakage.

One deterministic image per class is reserved as an external audit set.  The
remaining images are center-cropped to the model input size and appended only
to the existing train split.  Existing validation/test rows are copied byte
for byte and their assignments never change.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
from collections import Counter
from pathlib import Path

from PIL import Image, ImageOps


FIELDS = [
    "sample_id", "path", "label", "is_ood", "source_id", "license_id",
    "group_id", "split", "split_hint", "sha256", "dhash", "duplicate_of",
    "width", "height", "mime", "status",
]


def sha256_file(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def dhash(image: Image.Image, size: int = 8) -> str:
    gray = image.convert("L").resize((size + 1, size))
    pixels = list(gray.getdata())
    bits = 0
    for row in range(size):
        for col in range(size):
            left = pixels[row * (size + 1) + col]
            right = pixels[row * (size + 1) + col + 1]
            bits = (bits << 1) | int(left > right)
    return f"{bits:016x}"


def hamming(first: str, second: str) -> int:
    return (int(first, 16) ^ int(second, 16)).bit_count()


def safe_license_id(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return f"commons_{normalized or 'open_license'}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-manifest", type=Path, required=True)
    parser.add_argument("--base-report", type=Path, required=True)
    parser.add_argument("--curated", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--output-manifest", type=Path, required=True)
    parser.add_argument("--audit-output", type=Path, required=True)
    parser.add_argument("--audit-per-class", type=int, default=1)
    args = parser.parse_args()

    with args.base_manifest.open("r", encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))
    report = json.loads(args.base_report.read_text(encoding="utf-8"))
    provenance_doc = json.loads(
        (args.curated / "provenance.json").read_text(encoding="utf-8")
    )
    provenance = {
        Path(row["merged_local_path"]).name: row for row in provenance_doc["rows"]
    }

    existing_hashes = {row["sha256"] for row in rows if row["sha256"]}
    existing_dhashes: dict[str, list[str]] = {}
    for row in rows:
        if row["status"] == "ok" and row["dhash"]:
            existing_dhashes.setdefault(row["label"], []).append(row["dhash"])

    candidates: dict[str, list[Path]] = {}
    for path in sorted(args.curated.glob("*/*")):
        if path.is_file() and path.name != "provenance.json":
            candidates.setdefault(path.parent.name, []).append(path)

    audit_paths: set[Path] = set()
    for label, paths in candidates.items():
        ordered = sorted(paths, key=lambda path: hashlib.sha256(path.name.encode()).hexdigest())
        reserve = min(args.audit_per_class, max(0, len(ordered) - 3))
        audit_paths.update(ordered[:reserve])

    appended: list[dict[str, str]] = []
    audit_rows: list[dict] = []
    skipped_near_duplicates: list[dict] = []
    args.data_root.mkdir(parents=True, exist_ok=True)
    args.audit_output.mkdir(parents=True, exist_ok=True)

    for label, paths in sorted(candidates.items()):
        for source in paths:
            meta = provenance[source.name]
            with Image.open(source) as opened:
                image = ImageOps.exif_transpose(opened).convert("RGB")
                fitted = ImageOps.fit(
                    image, (224, 224), method=Image.Resampling.BILINEAR,
                    centering=(0.5, 0.5),
                )
            image_dhash = dhash(fitted)
            nearest = min(
                (hamming(image_dhash, value) for value in existing_dhashes.get(label, [])),
                default=64,
            )
            if nearest <= 4:
                skipped_near_duplicates.append(
                    {"label": label, "file": source.name, "nearest_dhash_distance": nearest}
                )
                continue

            filename = f"open_{meta['sha256'][:16]}.jpg"
            if source in audit_paths:
                destination = args.audit_output / label / filename
            else:
                destination = args.data_root / label / filename
            destination.parent.mkdir(parents=True, exist_ok=True)
            fitted.save(destination, "JPEG", quality=95, subsampling=0)
            processed_sha = sha256_file(destination)
            if processed_sha in existing_hashes:
                destination.unlink(missing_ok=True)
                continue

            base_meta = {
                "label": label,
                "path": destination.as_posix(),
                "sha256": processed_sha,
                "dhash": image_dhash,
                "source_sha256": meta["sha256"],
                "license": meta["license"],
                "license_url": meta["license_url"],
                "description_url": meta["description_url"],
                "artist": meta["artist"],
            }
            if source in audit_paths:
                audit_rows.append(base_meta)
                continue

            relative = destination.relative_to(args.data_root).as_posix()
            sample_id = hashlib.sha256(
                f"open_license_reviewed:{relative}".encode()
            ).hexdigest()[:24]
            appended.append(
                {
                    "sample_id": sample_id,
                    "path": relative,
                    "label": label,
                    "is_ood": "false",
                    "source_id": "open_license_reviewed",
                    "license_id": safe_license_id(meta["license"]),
                    "group_id": f"open:{meta['sha256']}",
                    "split": "train",
                    "split_hint": "train",
                    "sha256": processed_sha,
                    "dhash": image_dhash,
                    "duplicate_of": "",
                    "width": "224",
                    "height": "224",
                    "mime": "image/jpeg",
                    "status": "ok",
                }
            )
            existing_hashes.add(processed_sha)
            existing_dhashes.setdefault(label, []).append(image_dhash)

    combined = rows + appended
    args.output_manifest.parent.mkdir(parents=True, exist_ok=True)
    with args.output_manifest.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(combined)

    added_counts = Counter(row["label"] for row in appended)
    distribution = Counter(
        (row["label"], row["split"], row["status"]) for row in combined
    )
    report["dataset_version"] = sha256_file(args.output_manifest)
    report["manifest"] = args.output_manifest.as_posix()
    report["data_root_hint"] = args.data_root.as_posix()
    report["samples_total"] = len(combined)
    report["samples_valid"] = sum(row["status"] == "ok" for row in combined)
    report["distribution"] = [
        {"label": key[0], "split": key[1], "status": key[2], "count": count}
        for key, count in sorted(distribution.items())
    ]
    report["train_only_extension"] = {
        "source": "Human-reviewed open-license candidates from Wikimedia Commons and Openverse",
        "added_total": len(appended),
        "added_by_label": dict(sorted(added_counts.items())),
        "audit_total": len(audit_rows),
        "skipped_near_duplicate_total": len(skipped_near_duplicates),
        "existing_validation_rows_modified": 0,
        "existing_test_rows_modified": 0,
    }
    for check in report.get("scope_checks", []):
        added = added_counts.get(check["label"], 0)
        if added:
            check["samples"] += added
            check.setdefault("splits", {})["train"] = check["splits"].get("train", 0) + added
            check.setdefault("sources", []).append("open_license_reviewed")
            check["sources"] = sorted(set(check["sources"]))

    args.output_manifest.with_suffix(".report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (args.audit_output / "audit_manifest.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "policy": "external audit only; never used for training or threshold selection",
                "rows": audit_rows,
                "skipped_near_duplicates": skipped_near_duplicates,
            },
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "added_total": len(appended),
                "added_by_label": dict(sorted(added_counts.items())),
                "audit_total": len(audit_rows),
                "skipped_near_duplicates": len(skipped_near_duplicates),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
