"""Apply a human visual-review decision to downloaded Commons candidates.

The accepted files are copied into a separate train-only directory.  The
original attribution file is preserved and every row receives an explicit
review status and reason so no image can silently enter model training.
"""

from __future__ import annotations

import argparse
import json
import shutil
from collections import Counter
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--decisions", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rows = json.loads(
        (args.candidates / "attribution.json").read_text(encoding="utf-8")
    )
    decisions = json.loads(args.decisions.read_text(encoding="utf-8"))
    accepted = {
        (label, index)
        for label, indexes in decisions["accepted_sorted_indexes"].items()
        for index in indexes
    }
    counts: Counter[str] = Counter()
    reviewed: list[dict] = []

    args.output.mkdir(parents=True, exist_ok=True)
    by_label: dict[str, list[dict]] = {}
    for row in rows:
        by_label.setdefault(str(row["label"]), []).append(row)

    for label, label_rows in sorted(by_label.items()):
        for index, row in enumerate(
            sorted(label_rows, key=lambda item: item["local_path"]), start=1
        ):
            row = dict(row)
            row["visual_review_index"] = index
            if (label, index) in accepted:
                row["review_status"] = "accepted_train_only"
                row["review_reason"] = "clear canonical subject after visual review"
                source = args.candidates / row["local_path"]
                destination = args.output / label / source.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
                counts[label] += 1
            else:
                row["review_status"] = "rejected_visual_review"
                row["review_reason"] = (
                    "ambiguous, mixed, processed, off-topic, or overlaps another class"
                )
            reviewed.append(row)

    report = {
        "schema_version": 1,
        "policy": "human-reviewed; train-only; validation and test unchanged",
        "accepted_total": sum(counts.values()),
        "accepted_by_label": dict(sorted(counts.items())),
        "candidate_total": len(rows),
        "rejected_total": len(rows) - sum(counts.values()),
        "rows": reviewed,
    }
    (args.output / "curation_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({key: report[key] for key in report if key != "rows"}, indent=2))


if __name__ == "__main__":
    main()
