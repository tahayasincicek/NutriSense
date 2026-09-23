from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score, recall_score

from nutrisense_ml.augmentation import RandomApply  # Registers saved custom layer.
from nutrisense_ml.data import build_dataset, read_manifest


def _metrics(y_true: np.ndarray, probabilities: np.ndarray) -> dict[str, float]:
    predicted = probabilities.argmax(axis=1)
    return {
        "accuracy": float(accuracy_score(y_true, predicted)),
        "macro_f1": float(f1_score(y_true, predicted, average="macro", zero_division=0)),
        "macro_recall": float(recall_score(y_true, predicted, average="macro", zero_division=0)),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--split", choices=("validation", "test"), required=True)
    parser.add_argument("--batch-size", type=int, default=96)
    parser.add_argument(
        "--method",
        choices=("all", "original", "four_view"),
        default="all",
        help="Use 'all' for validation selection and a fixed method for the sealed test split.",
    )
    args = parser.parse_args()

    labels = [line.strip() for line in args.labels.read_text(encoding="utf-8").splitlines() if line.strip()]
    rows = read_manifest(args.manifest, args.data_root, args.split)
    dataset = build_dataset(rows, labels, 224, 224, args.batch_size, False, 42, decoder="native_prefitted")
    model = tf.keras.models.load_model(args.model, compile=False)

    truth: list[np.ndarray] = []
    predictions: dict[str, list[np.ndarray]] = {
        "original": [],
        "original_flip": [],
        "original_crop90": [],
        "four_view": [],
        "weighted_four_view": [],
    }
    if args.method != "all":
        predictions = {args.method: []}
    for images, target in dataset:
        original = model(images, training=False).numpy()
        truth.append(target.numpy())
        if "original" in predictions:
            predictions["original"].append(original)
        if args.method == "original":
            continue
        flipped = model(tf.image.flip_left_right(images), training=False).numpy()
        crop = tf.image.resize(tf.image.central_crop(images, 0.90), [224, 224], antialias=True)
        cropped = model(crop, training=False).numpy()
        crop_flipped = model(tf.image.flip_left_right(crop), training=False).numpy()
        if "original_flip" in predictions:
            predictions["original_flip"].append((original + flipped) / 2.0)
        if "original_crop90" in predictions:
            predictions["original_crop90"].append((original + cropped) / 2.0)
        predictions["four_view"].append((original + flipped + cropped + crop_flipped) / 4.0)
        if "weighted_four_view" in predictions:
            predictions["weighted_four_view"].append(
                0.50 * original + 0.20 * flipped + 0.20 * cropped + 0.10 * crop_flipped
            )

    y_true = np.concatenate(truth)
    results = {
        name: _metrics(y_true, np.concatenate(parts))
        for name, parts in predictions.items()
    }
    print(json.dumps({"split": args.split, "samples": len(y_true), "results": results}, indent=2))


if __name__ == "__main__":
    main()
