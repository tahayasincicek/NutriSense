#!/usr/bin/env python3
"""Compare aggregate and per-class metrics from two evaluation JSON files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--classes", nargs="*", default=[])
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    candidate = json.loads(args.candidate.read_text(encoding="utf-8"))

    for metric in ("accuracy", "macro_f1", "top_k_accuracy"):
        old = float(baseline[metric])
        new = float(candidate[metric])
        print(f"{metric}: {old:.9f} -> {new:.9f} ({new - old:+.9f})")

    deltas = []
    for label, old_metrics in baseline["per_class"].items():
        if label in {"macro avg", "weighted avg"}:
            continue
        if not isinstance(old_metrics, dict) or "f1-score" not in old_metrics:
            continue
        old = float(old_metrics["f1-score"])
        new = float(candidate["per_class"][label]["f1-score"])
        deltas.append((new - old, label, old, new))

    print(
        "classes: "
        f"improved={sum(delta > 1e-12 for delta, *_ in deltas)} "
        f"worse={sum(delta < -1e-12 for delta, *_ in deltas)} "
        f"same={sum(abs(delta) <= 1e-12 for delta, *_ in deltas)}"
    )
    for label in args.classes:
        old = float(baseline["per_class"][label]["f1-score"])
        new = float(candidate["per_class"][label]["f1-score"])
        print(f"{label}: {old:.6f} -> {new:.6f} ({new - old:+.6f})")


if __name__ == "__main__":
    main()
