"""Summarize candidate consistency scores for curation planning."""

from __future__ import annotations

import argparse
import json
import statistics
from collections import defaultdict
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scores", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows = json.loads(args.scores.read_text(encoding="utf-8"))
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        grouped[str(row["label"])].append(row)

    classes = []
    for label, items in sorted(grouped.items()):
        probabilities = [float(item["expected_probability"]) for item in items]
        ranks = [int(item["expected_rank"]) for item in items]
        classes.append(
            {
                "label": label,
                "candidates": len(items),
                "rank1": sum(rank == 1 for rank in ranks),
                "top3": sum(rank <= 3 for rank in ranks),
                "top5": sum(rank <= 5 for rank in ranks),
                "median_expected_probability": statistics.median(probabilities),
            }
        )
    report = {
        "candidate_total": len(rows),
        "label_total": len(classes),
        "rank1_total": sum(item["rank1"] for item in classes),
        "top3_total": sum(item["top3"] for item in classes),
        "top5_total": sum(item["top5"] for item in classes),
        "classes": classes,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "classes"}, indent=2))


if __name__ == "__main__":
    main()
