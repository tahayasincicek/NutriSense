from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, ImageOps, UnidentifiedImageError

from .common import load_json, sha256_file, stable_hash, utc_now, validate_config, write_json

MANIFEST_FIELDS = [
    "sample_id", "path", "label", "is_ood", "source_id", "license_id", "group_id",
    "split", "split_hint", "sha256", "dhash", "duplicate_of", "width", "height",
    "mime", "status",
]
INTAKE_REQUIRED = {"path", "label", "source_id", "license_id", "group_id"}


class UnionFind:
    def __init__(self, values: Iterable[str]) -> None:
        self.parent = {value: value for value in values}

    def find(self, value: str) -> str:
        while self.parent[value] != value:
            self.parent[value] = self.parent[self.parent[value]]
            value = self.parent[value]
        return value

    def union(self, first: str, second: str) -> None:
        a, b = self.find(first), self.find(second)
        if a != b:
            self.parent[max(a, b)] = min(a, b)


def image_dhash(image: Image.Image, size: int = 8) -> str:
    gray = ImageOps.exif_transpose(image).convert("L").resize((size + 1, size))
    pixels = list(gray.getdata())
    bits = 0
    for row in range(size):
        for col in range(size):
            bits = (bits << 1) | int(pixels[row * (size + 1) + col] > pixels[row * (size + 1) + col + 1])
    return f"{bits:0{size * size // 4}x}"


def hamming_hex(first: str, second: str) -> int:
    return (int(first, 16) ^ int(second, 16)).bit_count()


def inspect_image(path: Path) -> dict[str, Any]:
    try:
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            transposed = ImageOps.exif_transpose(image)
            transposed.load()
            return {
                "sha256": sha256_file(path),
                "dhash": image_dhash(transposed),
                "width": transposed.width,
                "height": transposed.height,
                "mime": Image.MIME.get(image.format, "application/octet-stream"),
                "status": "ok",
            }
    except (OSError, ValueError, UnidentifiedImageError) as exc:
        return {"sha256": "", "dhash": "", "width": 0, "height": 0, "mime": "", "status": f"corrupt:{type(exc).__name__}"}


def read_intake(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = INTAKE_REQUIRED - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Intake CSV missing columns: {sorted(missing)}")
        return [{key: (value or "").strip() for key, value in row.items()} for row in reader]


def _assign_groups(rows: list[dict[str, Any]], ratios: dict[str, float], seed: int) -> None:
    valid = [row for row in rows if row["status"] == "ok"]
    groups = sorted({row["effective_group"] for row in valid})
    group_sizes = Counter(row["effective_group"] for row in valid)
    hints: dict[str, set[str]] = defaultdict(set)
    for row in valid:
        if row["split_hint"]:
            hints[row["effective_group"]].add(row["split_hint"])
    for group, values in hints.items():
        if len(values) > 1 or not values <= {"train", "validation", "test"}:
            raise ValueError(f"Group {group} has conflicting/invalid split_hint values: {values}")

    assigned: dict[str, str] = {}
    counts = Counter()
    for group in groups:
        if hints[group]:
            split = next(iter(hints[group]))
            assigned[group] = split
            counts[split] += group_sizes[group]

    total = sum(group_sizes.values())
    target = {key: total * ratios[key] for key in ratios}
    unlocked = [group for group in groups if group not in assigned]
    unlocked.sort(key=lambda group: stable_hash(f"{seed}:{group}"))
    for group in unlocked:
        split = max(("train", "validation", "test"), key=lambda key: target[key] - counts[key])
        assigned[group] = split
        counts[split] += group_sizes[group]
    for row in valid:
        row["split"] = assigned[row["effective_group"]]


def build_manifest(
    intake_path: Path,
    data_root: Path,
    config_path: Path,
    licenses_path: Path,
    output_path: Path,
    allow_test_fixtures: bool = False,
    near_duplicate_distance: int = 4,
) -> dict[str, Any]:
    config = load_json(config_path)
    validate_config(config)
    licenses_doc = load_json(licenses_path)
    licenses = {item["id"]: item for item in licenses_doc["sources"]}
    allowed_labels = {item["id"] for item in config["classes"]}
    ood_label = config["ood"]["label"]
    raw_rows = read_intake(intake_path)
    if not raw_rows:
        raise ValueError("Intake CSV is empty")

    rows: list[dict[str, Any]] = []
    root = data_root.resolve()
    for index, raw in enumerate(raw_rows):
        label = raw["label"]
        if label not in allowed_labels | {ood_label}:
            raise ValueError(f"Unsupported label at intake row {index + 2}: {label}")
        license_record = licenses.get(raw["license_id"])
        if license_record is None:
            raise ValueError(f"Unknown license_id at intake row {index + 2}: {raw['license_id']}")
        if not license_record["allowed_for_training"]:
            if not (allow_test_fixtures and raw["license_id"] == "synthetic_test_only"):
                raise ValueError(f"License {raw['license_id']} is not approved for training")
        image_path = (root / raw["path"]).resolve()
        try:
            relative = image_path.relative_to(root).as_posix()
        except ValueError as exc:
            raise ValueError(f"Path escapes data root: {raw['path']}") from exc
        details = inspect_image(image_path)
        row = {
            "sample_id": stable_hash(f"{raw['source_id']}:{relative}")[:24],
            "path": relative,
            "label": label,
            "is_ood": str(label == ood_label).lower(),
            "source_id": raw["source_id"],
            "license_id": raw["license_id"],
            "group_id": raw["group_id"],
            "split": "",
            "split_hint": raw.get("split_hint", ""),
            "duplicate_of": "",
            **details,
        }
        rows.append(row)

    valid = [row for row in rows if row["status"] == "ok"]
    sha_labels: dict[str, set[str]] = defaultdict(set)
    for row in valid:
        sha_labels[row["sha256"]].add(row["label"])
    conflicts = {digest: labels for digest, labels in sha_labels.items() if len(labels) > 1}
    if conflicts:
        raise ValueError(f"Exact duplicate images have conflicting labels ({len(conflicts)} hashes)")

    group_uf = UnionFind(row["group_id"] for row in valid)
    by_label: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in valid:
        by_label[row["label"]].append(row)
    for label_rows in by_label.values():
        for i, first in enumerate(label_rows):
            for second in label_rows[i + 1 :]:
                if first["sha256"] == second["sha256"] or hamming_hex(first["dhash"], second["dhash"]) <= near_duplicate_distance:
                    group_uf.union(first["group_id"], second["group_id"])
                    if not second["duplicate_of"]:
                        second["duplicate_of"] = first["sample_id"]
    for row in valid:
        row["effective_group"] = group_uf.find(row["group_id"])

    supported = [row for row in rows if row["label"] != ood_label]
    _assign_groups(supported, config["splits"], int(config["seed"]))
    ood = [row for row in rows if row["label"] == ood_label]
    if ood:
        _assign_groups(ood, {"train": 0.0, "validation": 0.5, "test": 0.5}, int(config["seed"]) + 1)
        if any(row["split"] == "train" for row in ood if row["status"] == "ok"):
            raise AssertionError("OOD samples must not be silently trained as a food class")

    for row in rows:
        row.pop("effective_group", None)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS)
        writer.writeheader()
        writer.writerows({field: row.get(field, "") for field in MANIFEST_FIELDS} for row in rows)
    dataset_version = sha256_file(output_path)
    distribution = Counter((row["label"], row["split"], row["status"]) for row in rows)
    report = {
        "schema_version": 1,
        "status": "prepared",
        "created_at": utc_now(),
        "scope_id": config["scope_id"],
        "seed": config["seed"],
        "dataset_version": dataset_version,
        "manifest": output_path.as_posix(),
        "data_root_hint": root.as_posix(),
        "samples_total": len(rows),
        "samples_valid": len(valid),
        "samples_corrupt": len(rows) - len(valid),
        "exact_or_near_duplicates": sum(bool(row["duplicate_of"]) for row in rows),
        "distribution": [
            {"label": key[0], "split": key[1], "status": key[2], "count": count}
            for key, count in sorted(distribution.items())
        ],
    }
    class_requirements = {item["id"]: item for item in config["classes"]}
    scope_checks = []
    for label, requirement in class_requirements.items():
        label_rows = [row for row in valid if row["label"] == label]
        groups = {row["group_id"] for row in label_rows}
        split_counts = Counter(row["split"] for row in label_rows)
        violations = []
        if len(label_rows) < int(requirement.get("target", 0)):
            violations.append(f"samples {len(label_rows)} < target {requirement.get('target')}")
        if len(groups) < int(requirement.get("min_groups", 0)):
            violations.append(f"groups {len(groups)} < minimum {requirement.get('min_groups')}")
        if any(split_counts[name] == 0 for name in ("train", "validation", "test")):
            violations.append("one or more required splits are empty")
        scope_checks.append({"label": label, "samples": len(label_rows), "groups": len(groups), "splits": dict(split_counts), "sources": sorted({row["source_id"] for row in label_rows}), "licenses": sorted({row["license_id"] for row in label_rows}), "ready": not violations, "violations": violations})
    ood_rows = [row for row in valid if row["label"] == ood_label]
    ood_violations = []
    if len(ood_rows) < int(config["ood"].get("target", 0)):
        ood_violations.append(f"OOD samples {len(ood_rows)} < target {config['ood'].get('target')}")
    if not {row["split"] for row in ood_rows} >= {"validation", "test"}:
        ood_violations.append("OOD validation and test splits are both required")
    report["scope_checks"] = scope_checks
    report["ood_check"] = {"samples": len(ood_rows), "ready": not ood_violations, "violations": ood_violations}
    report["scope_ready_for_training"] = all(item["ready"] for item in scope_checks) and not ood_violations
    write_json(output_path.with_suffix(".report.json"), report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate images and create a leakage-resistant manifest")
    parser.add_argument("--intake", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--licenses", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--near-duplicate-distance", type=int, default=4)
    parser.add_argument("--allow-test-fixtures", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    report = build_manifest(
        args.intake, args.data_root, args.config, args.licenses, args.output,
        args.allow_test_fixtures, args.near_duplicate_distance,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
