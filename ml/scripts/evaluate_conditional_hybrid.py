#!/usr/bin/env python3
"""Final evaluation for the frozen conditional two-model decision rule."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score, top_k_accuracy_score

from nutrisense_ml import augmentation as _augmentation  # noqa: F401
from nutrisense_ml.data import build_dataset, read_manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--primary", type=Path, required=True)
    parser.add_argument("--fallback", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--split", choices=["validation", "test"], required=True)
    parser.add_argument("--trigger-classes", nargs="+", required=True)
    parser.add_argument("--trigger-top-k", type=int, default=2)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    labels = args.labels.read_text(encoding="utf-8").splitlines()
    trigger_indexes = [labels.index(label) for label in args.trigger_classes]
    rows = read_manifest(args.manifest, args.data_root, args.split)
    dataset = build_dataset(rows, labels, 224, 224, 96, False, 2209, decoder="native_prefitted")
    images = dataset.map(lambda image, _: image)
    truth = np.asarray([labels.index(row["label"]) for row in rows])
    primary = tf.keras.models.load_model(args.primary, compile=False).predict(images, verbose=0)
    top_k = np.argpartition(primary, -args.trigger_top_k, axis=1)[:, -args.trigger_top_k:]
    gate = np.any(np.isin(top_k, trigger_indexes), axis=1)
    prediction = primary.argmax(axis=1)

    # The offline evaluator calculates the fallback in one batch. The app runs it
    # only for gated images, represented by fallback_usage below.
    fallback = tf.keras.models.load_model(args.fallback, compile=False).predict(images, verbose=0)
    fallback_prediction = fallback.argmax(axis=1)
    prediction[gate] = fallback_prediction[gate]
    class_f1 = f1_score(
        truth, prediction, labels=list(range(len(labels))), average=None, zero_division=0
    )
    report = {
        "split": args.split,
        "samples": len(rows),
        "accuracy": float(accuracy_score(truth, prediction)),
        "macro_f1": float(class_f1.mean()),
        "primary_top3_accuracy": float(
            top_k_accuracy_score(truth, primary, k=3, labels=list(range(len(labels))))
        ),
        "fallback_usage": float(gate.mean()),
        "trigger_top_k": args.trigger_top_k,
        "trigger_classes": args.trigger_classes,
        "critical_f1": {
            label: float(class_f1[index])
            for label, index in zip(args.trigger_classes, trigger_indexes)
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
