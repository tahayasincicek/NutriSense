#!/usr/bin/env python3
"""Summarize the largest directional and symmetric class confusions."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("metrics", type=Path)
    parser.add_argument("--labels", type=Path)
    parser.add_argument("--limit", type=int, default=30)
    args = parser.parse_args()

    report = json.loads(args.metrics.read_text(encoding="utf-8"))
    per_class = report["per_class"]
    labels_path = args.labels or args.metrics.with_name("labels.txt")
    labels = labels_path.read_text(encoding="utf-8").splitlines()
    if len(labels) != len(report["confusion_matrix"]):
        raise ValueError("Label count does not match the confusion matrix")
    matrix = report["confusion_matrix"]

    directional = []
    symmetric: dict[tuple[str, str], int] = defaultdict(int)
    for true_index, true_label in enumerate(labels):
        support = max(1, int(per_class[true_label]["support"]))
        for predicted_index, predicted_label in enumerate(labels):
            if true_index == predicted_index:
                continue
            count = int(matrix[true_index][predicted_index])
            if not count:
                continue
            directional.append((count / support, count, true_label, predicted_label))
            pair = tuple(sorted((true_label, predicted_label)))
            symmetric[pair] += count

    print("directional")
    for rate, count, true_label, predicted_label in sorted(directional, reverse=True)[: args.limit]:
        print(f"{true_label} -> {predicted_label}: {count} ({rate:.1%})")
    print("symmetric")
    for (left, right), count in sorted(symmetric.items(), key=lambda item: item[1], reverse=True)[: args.limit]:
        print(f"{left} <-> {right}: {count}")


if __name__ == "__main__":
    main()
