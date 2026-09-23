#!/usr/bin/env python3
"""Tune a few class probability multipliers on one validation half and audit the other."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score

from nutrisense_ml import augmentation as _augmentation  # noqa: F401
from nutrisense_ml.data import build_dataset, read_manifest


def report(truth: np.ndarray, probabilities: np.ndarray, class_indexes: list[int]) -> dict:
    return report_predictions(truth, probabilities.argmax(axis=1), probabilities.shape[1], class_indexes)


def report_predictions(
    truth: np.ndarray,
    predicted: np.ndarray,
    class_count: int,
    class_indexes: list[int],
) -> dict:
    values = f1_score(
        truth,
        predicted,
        labels=list(range(class_count)),
        average=None,
        zero_division=0,
    )
    return {
        "accuracy": float(accuracy_score(truth, predicted)),
        "macro_f1": float(values.mean()),
        "critical_f1": {str(index): float(values[index]) for index in class_indexes},
    }


def apply_bias(probabilities: np.ndarray, indexes: list[int], factors: np.ndarray) -> np.ndarray:
    adjusted = probabilities.copy()
    adjusted[:, indexes] *= factors
    adjusted /= adjusted.sum(axis=1, keepdims=True)
    return adjusted


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--classes", nargs="+", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    labels = args.labels.read_text(encoding="utf-8").splitlines()
    indexes = [labels.index(label) for label in args.classes]
    rows = read_manifest(args.manifest, args.data_root, "validation")
    dataset = build_dataset(rows, labels, 224, 224, 96, False, 2209, decoder="native_prefitted")
    images = dataset.map(lambda image, _: image)
    truth = np.asarray([labels.index(row["label"]) for row in rows])
    baseline = tf.keras.models.load_model(args.baseline, compile=False).predict(images, verbose=0)
    candidate = tf.keras.models.load_model(args.candidate, compile=False).predict(images, verbose=0)
    np.savez_compressed(
        args.output.with_suffix(".npz"),
        truth=truth,
        baseline=baseline,
        candidate=candidate,
    )

    # Alternating examples within each class give deterministic, stratified halves.
    counters = np.zeros(len(labels), dtype=np.int64)
    calibration_mask = np.zeros(len(truth), dtype=bool)
    for row_index, label_index in enumerate(truth):
        calibration_mask[row_index] = counters[label_index] % 2 == 0
        counters[label_index] += 1
    audit_mask = ~calibration_mask

    base_cal = report(truth[calibration_mask], baseline[calibration_mask], indexes)
    factors = np.ones(len(indexes), dtype=np.float32)
    grids = [
        np.arange(0.70, 1.31, 0.05),
        np.arange(0.85, 1.16, 0.025),
        np.arange(0.94, 1.061, 0.01),
    ]
    for grid in grids:
        for position in range(len(indexes)):
            best_factor = float(factors[position])
            best_score = -1e9
            for value in grid:
                trial = factors.copy()
                trial[position] = value
                metrics = report(
                    truth[calibration_mask],
                    apply_bias(candidate[calibration_mask], indexes, trial),
                    indexes,
                )
                deficits = sum(
                    max(0.0, base_cal["critical_f1"][str(index)] - metrics["critical_f1"][str(index)])
                    for index in indexes
                )
                score = metrics["macro_f1"] - 2.0 * deficits
                if score > best_score:
                    best_score = score
                    best_factor = float(value)
            factors[position] = best_factor

    baseline_pred = baseline.argmax(axis=1)
    candidate_pred = candidate.argmax(axis=1)
    baseline_is_critical = np.isin(baseline_pred, indexes)
    candidate_is_critical = np.isin(candidate_pred, indexes)
    hybrid_predictions = {}
    for name, gate in {
        "candidate_top1_critical": candidate_is_critical,
        "baseline_top1_critical": baseline_is_critical,
        "either_top1_critical": baseline_is_critical | candidate_is_critical,
    }.items():
        prediction = candidate_pred.copy()
        prediction[gate] = baseline_pred[gate]
        hybrid_predictions[name] = prediction

    output = {
        "classes": args.classes,
        "factors": {label: float(value) for label, value in zip(args.classes, factors)},
        "calibration": {
            "baseline": base_cal,
            "candidate_raw": report(truth[calibration_mask], candidate[calibration_mask], indexes),
            "candidate_biased": report(
                truth[calibration_mask],
                apply_bias(candidate[calibration_mask], indexes, factors),
                indexes,
            ),
        },
        "audit": {
            "baseline": report(truth[audit_mask], baseline[audit_mask], indexes),
            "candidate_raw": report(truth[audit_mask], candidate[audit_mask], indexes),
            "candidate_biased": report(
                truth[audit_mask], apply_bias(candidate[audit_mask], indexes, factors), indexes
            ),
        },
        "full_hybrid": {
            name: {
                **report_predictions(truth, prediction, len(labels), indexes),
                "baseline_usage": float(np.mean(prediction != candidate_pred)),
            }
            for name, prediction in hybrid_predictions.items()
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
