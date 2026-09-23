#!/usr/bin/env python3
"""Tune four-view inference weights on one validation half and verify on the other."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score

from nutrisense_ml import augmentation as _augmentation  # Register custom layers.
from nutrisense_ml.data import build_dataset, read_manifest


def metrics(truth: np.ndarray, probabilities: np.ndarray) -> dict[str, float]:
    predicted = probabilities.argmax(axis=1)
    return {
        "accuracy": float(accuracy_score(truth, predicted)),
        "macro_f1": float(f1_score(truth, predicted, average="macro", zero_division=0)),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=96)
    parser.add_argument("--parts", type=int, default=8, help="Simplex grid denominator")
    args = parser.parse_args()

    labels = args.labels.read_text(encoding="utf-8").splitlines()
    rows = read_manifest(args.manifest, args.data_root, "validation")
    truth = np.asarray([labels.index(row["label"]) for row in rows])
    tune = np.asarray(
        [int(hashlib.sha256(row["sample_id"].encode()).hexdigest(), 16) % 2 == 0 for row in rows]
    )
    dataset = build_dataset(
        rows, labels, 224, 224, args.batch_size, False, 2209,
        decoder="native_prefitted",
    )
    model = tf.keras.models.load_model(args.model, compile=False)
    views: list[list[np.ndarray]] = [[], [], [], []]
    for images, _ in dataset:
        crop = tf.image.resize(tf.image.central_crop(images, 0.90), [224, 224], antialias=True)
        batches = (images, tf.image.flip_left_right(images), crop, tf.image.flip_left_right(crop))
        for index, batch in enumerate(batches):
            views[index].append(model(batch, training=False).numpy())
    probabilities = [np.concatenate(parts) for parts in views]

    candidates = []
    for integers in itertools.product(range(args.parts + 1), repeat=4):
        if sum(integers) != args.parts:
            continue
        weights = np.asarray(integers, dtype=np.float64) / args.parts
        combined = sum(weight * prediction for weight, prediction in zip(weights, probabilities))
        result = metrics(truth[tune], combined[tune])
        candidates.append((result["accuracy"] + result["macro_f1"], weights, result))
    _, best_weights, tune_metrics = max(candidates, key=lambda item: item[0])

    equal_weights = np.full(4, 0.25)
    equal = sum(weight * prediction for weight, prediction in zip(equal_weights, probabilities))
    best = sum(weight * prediction for weight, prediction in zip(best_weights, probabilities))
    report = {
        "samples": len(rows),
        "tune_samples": int(tune.sum()),
        "holdout_samples": int((~tune).sum()),
        "view_order": ["original", "original_flip", "crop90", "crop90_flip"],
        "equal_weights": equal_weights.tolist(),
        "best_weights": best_weights.tolist(),
        "equal_tune": metrics(truth[tune], equal[tune]),
        "best_tune": tune_metrics,
        "equal_holdout": metrics(truth[~tune], equal[~tune]),
        "best_holdout": metrics(truth[~tune], best[~tune]),
        "equal_full": metrics(truth, equal),
        "best_full": metrics(truth, best),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
