"""Promote selected OOD folders into supported classes without data leakage."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path


def read_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError(f"Manifest has no header: {path}")
        return list(reader.fieldnames), list(reader)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-manifest", type=Path, required=True)
    parser.add_argument("--expanded-manifest", type=Path, required=True)
    parser.add_argument("--labels", nargs="+", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    fields, base_rows = read_rows(args.base_manifest)
    expanded_fields, expanded_rows = read_rows(args.expanded_manifest)
    if fields != expanded_fields:
        raise ValueError("Manifest schemas do not match")

    labels = set(args.labels)
    promoted = [row for row in expanded_rows if row["label"] in labels]
    found = {row["label"] for row in promoted}
    missing = labels - found
    if missing:
        raise ValueError(f"Expanded manifest has no samples for: {sorted(missing)}")

    promoted_paths = {row["path"] for row in promoted}
    retained = [row for row in base_rows if row["path"] not in promoted_paths]
    collisions = {row["path"] for row in retained} & promoted_paths
    if collisions:
        raise ValueError("Promoted paths remain in the base rows")

    output_rows = retained + promoted
    seen_paths: set[str] = set()
    for row in output_rows:
        if row["path"] in seen_paths:
            raise ValueError(f"Duplicate path after expansion: {row['path']}")
        seen_paths.add(row["path"])

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(output_rows)

    distribution = Counter(
        (row["label"], row["split"], row["status"]) for row in output_rows
    )
    report = {
        "created_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "dataset_version": hashlib.sha256(args.output.read_bytes()).hexdigest(),
        "distribution": [
            {"label": label, "split": split, "status": status, "count": count}
            for (label, split, status), count in sorted(distribution.items())
        ],
        "promoted_labels": sorted(labels),
        "promoted_samples": len(promoted),
        "removed_ood_samples": len(base_rows) - len(retained),
        "scope_ready_for_training": True,
    }
    args.output.with_suffix(".report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    counts = Counter((row["label"], row["split"]) for row in promoted)
    print(f"rows={len(output_rows)} promoted={len(promoted)} removed_ood={len(base_rows)-len(retained)}")
    for label in sorted(labels):
        print(label, {split: counts[(label, split)] for split in ("train", "validation", "test")})


if __name__ == "__main__":
    main()
