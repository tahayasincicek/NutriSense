#!/usr/bin/env python3
"""Evaluate weight-space interpolation between compatible Keras classifiers."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score, top_k_accuracy_score

from nutrisense_ml import augmentation as _augmentation  # Register custom layers.
from nutrisense_ml.data import build_dataset, read_manifest


def metrics(
    truth: np.ndarray,
    probabilities: np.ndarray,
    labels: list[str],
    report_classes: list[str],
) -> dict[str, object]:
    predicted = probabilities.argmax(axis=1)
    report: dict[str, object] = {
        "accuracy": float(accuracy_score(truth, predicted)),
        "macro_f1": float(f1_score(truth, predicted, average="macro", zero_division=0)),
        "top3_accuracy": float(
            top_k_accuracy_score(
                truth,
                probabilities,
                k=3,
                labels=list(range(probabilities.shape[1])),
            )
        ),
    }
    per_class_f1 = f1_score(
        truth,
        predicted,
        labels=list(range(len(labels))),
        average=None,
        zero_division=0,
    )
    report["per_class_f1"] = {
        label: float(per_class_f1[labels.index(label)])
        for label in report_classes
    }
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--alphas", nargs="+", type=float, default=[0.25, 0.5, 0.75])
    parser.add_argument("--report-classes", nargs="*", default=[])
    parser.add_argument("--batch-size", type=int, default=96)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    if any(alpha < 0 or alpha > 1 for alpha in args.alphas):
        raise ValueError("Interpolation alphas must be between zero and one")
    labels = args.labels.read_text(encoding="utf-8").splitlines()
    unknown_report_classes = set(args.report_classes) - set(labels)
    if unknown_report_classes:
        raise ValueError(f"Unknown report classes: {sorted(unknown_report_classes)}")
    rows = read_manifest(args.manifest, args.data_root, "validation")
    dataset = build_dataset(
        rows,
        labels,
        224,
        224,
        args.batch_size,
        False,
        2209,
        decoder="native_prefitted",
    )
    truth = np.asarray([labels.index(row["label"]) for row in rows])

    baseline = tf.keras.models.load_model(args.baseline, compile=False)
    candidate = tf.keras.models.load_model(args.candidate, compile=False)
    baseline_weights = baseline.get_weights()
    candidate_weights = candidate.get_weights()
    if len(baseline_weights) != len(candidate_weights):
        raise ValueError("Models have different weight counts")
    for index, (left, right) in enumerate(zip(baseline_weights, candidate_weights)):
        if left.shape != right.shape:
            raise ValueError(f"Weight {index} has incompatible shapes")

    results: dict[str, dict[str, float]] = {}
    for alpha in args.alphas:
        baseline.set_weights(
            [
                (1.0 - alpha) * left + alpha * right
                for left, right in zip(baseline_weights, candidate_weights)
            ]
        )
        probabilities = baseline.predict(dataset.map(lambda image, _: image), verbose=0)
        results[f"{alpha:.4f}"] = metrics(
            truth, probabilities, labels, args.report_classes
        )
        print(alpha, results[f"{alpha:.4f}"], flush=True)

    report = {"alphas": results, "samples": len(rows)}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
