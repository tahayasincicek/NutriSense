"""Exclude visually anomalous training examples from selected food classes.

The input ranking is produced from embeddings of the current model.  Only
training rows are altered; validation and sealed test rows are never read or
changed by this script.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--outliers", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--classes", nargs="+", required=True)
    parser.add_argument("--fraction", type=float, default=0.15)
    args = parser.parse_args()
    if not 0 < args.fraction < 0.5:
        raise ValueError("fraction must be between 0 and 0.5")

    selected = set(args.classes)
    rankings = json.loads(args.outliers.read_text(encoding="utf-8"))
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for item in rankings:
        if item["label"] in selected:
            grouped[str(item["label"])].append(item)

    excluded: set[str] = set()
    for label in selected:
        items = sorted(grouped[label], key=lambda item: float(item["similarity"]))
        count = math.ceil(len(items) * args.fraction)
        excluded.update(str(item["path"]) for item in items[:count])

    with args.manifest.open("r", encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))
    for row in rows:
        if (
            row["split"] == "train"
            and row["label"] in selected
            and row["path"] in excluded
        ):
            row["status"] = "excluded_curated_outlier"

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Excluded {len(excluded)} train rows across {len(selected)} classes.")


if __name__ == "__main__":
    main()
