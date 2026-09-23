"""Merge reviewed acquisition batches while removing cross-batch duplicates."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from collections import Counter
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", nargs="+", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    counts: Counter[str] = Counter()
    provenance: list[dict] = []
    for batch in args.inputs:
        report = json.loads((batch / "curation_report.json").read_text("utf-8"))
        attribution = {
            row["sha256"]: row
            for row in report["rows"]
            if row["review_status"] == "accepted_train_only"
        }
        for source in sorted(batch.glob("*/*")):
            if not source.is_file() or source.name == "curation_report.json":
                continue
            sha256 = digest(source)
            if sha256 in seen:
                continue
            seen.add(sha256)
            label = source.parent.name
            destination = args.output / label / source.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            counts[label] += 1
            row = dict(attribution[sha256])
            row["merged_local_path"] = destination.relative_to(args.output).as_posix()
            provenance.append(row)

    output = {
        "schema_version": 1,
        "policy": "human-reviewed, SHA-256 deduplicated, train-only",
        "accepted_total": sum(counts.values()),
        "accepted_by_label": dict(sorted(counts.items())),
        "rows": provenance,
    }
    (args.output / "provenance.json").write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({key: output[key] for key in output if key != "rows"}, indent=2))


if __name__ == "__main__":
    main()
