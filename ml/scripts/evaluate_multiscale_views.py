"""Compare inference-time crop ensembles on a deterministic validation set."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score, recall_score

from nutrisense_ml import augmentation as _augmentation  # Register custom model layers.
from nutrisense_ml.data import build_dataset, read_manifest


STRATEGIES = {
    "current": [(1.0, 0.5), (0.9, 0.5)],
    "multiscale_equal": [(1.0, 0.2), (0.9, 0.2), (0.75, 0.2), (0.6, 0.2), (0.5, 0.2)],
    "center_equal": [(0.9, 0.25), (0.75, 0.25), (0.6, 0.25), (0.5, 0.25)],
    "center_weighted": [(1.0, 0.05), (0.9, 0.10), (0.75, 0.15), (0.6, 0.25), (0.5, 0.45)],
}


def view(images: tf.Tensor, fraction: float) -> tf.Tensor:
    if fraction == 1.0:
        return images
    return tf.image.resize(
        tf.image.central_crop(images, fraction), [224, 224], antialias=True
    )


def metrics(y_true: np.ndarray, probabilities: np.ndarray) -> dict[str, float]:
    predicted = probabilities.argmax(axis=1)
    top3 = np.argpartition(probabilities, -3, axis=1)[:, -3:]
    return {
        "accuracy": float(accuracy_score(y_true, predicted)),
        "top3_accuracy": float(np.mean(np.any(top3 == y_true[:, None], axis=1))),
        "macro_f1": float(f1_score(y_true, predicted, average="macro", zero_division=0)),
        "macro_recall": float(
            recall_score(y_true, predicted, average="macro", zero_division=0)
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--samples-per-class", type=int, default=20)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    labels = args.labels.read_text(encoding="utf-8").splitlines()
    rows = read_manifest(args.manifest, args.data_root, "validation")
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        grouped[row["label"]].append(row)
    selected = []
    for label in labels:
        ordered = sorted(grouped[label], key=lambda row: row["sample_id"])
        selected.extend(
            ordered if args.samples_per_class <= 0 else ordered[: args.samples_per_class]
        )

    model = tf.keras.models.load_model(args.model)
    dataset = build_dataset(
        selected, labels, 224, 224, 64, False, 2209, decoder="native_prefitted"
    )
    y_true_parts = []
    probability_parts = {name: [] for name in STRATEGIES}
    probability_parts.update(
        {
            "adaptive_disagreement": [],
            "adaptive_confidence_080": [],
            "adaptive_disagreement_or_confidence_080": [],
            "adaptive_disagreement_center_weighted": [],
            "adaptive_disagreement_or_confidence_080_center_weighted": [],
            "adaptive_disagreement_or_confidence_085_center_weighted": [],
            "adaptive_disagreement_or_confidence_070": [],
            "adaptive_disagreement_or_confidence_085": [],
            "adaptive_disagreement_or_confidence_090": [],
            "adaptive_disagreement_or_confidence_095": [],
            "adaptive_best_scale_080": [],
            "adaptive_confidence_weighted_080": [],
            "adaptive_margin_weighted_080": [],
        }
    )
    for images, batch_labels in dataset:
        y_true_parts.append(batch_labels.numpy())
        cache = {}
        for fraction in sorted(
            {fraction for strategy in STRATEGIES.values() for fraction, _ in strategy}
        ):
            images_view = view(images, fraction)
            cache[fraction] = (
                model(images_view, training=False).numpy()
                + model(tf.image.flip_left_right(images_view), training=False).numpy()
            ) / 2.0
        for name, strategy in STRATEGIES.items():
            probability_parts[name].append(
                sum(cache[fraction] * weight for fraction, weight in strategy)
            )
        current = (cache[1.0] + cache[0.9]) / 2.0
        multiscale = sum(cache[fraction] for fraction in (1.0, 0.9, 0.75, 0.6, 0.5)) / 5.0
        center_weighted = (
            cache[1.0] * 0.05
            + cache[0.9] * 0.10
            + cache[0.75] * 0.15
            + cache[0.6] * 0.25
            + cache[0.5] * 0.45
        )
        disagreement = cache[1.0].argmax(axis=1) != cache[0.9].argmax(axis=1)
        low_080 = current.max(axis=1) < 0.80
        low_085 = current.max(axis=1) < 0.85
        low_090 = current.max(axis=1) < 0.90
        low_095 = current.max(axis=1) < 0.95
        low_070 = current.max(axis=1) < 0.70
        stacked = np.stack(
            [cache[fraction] for fraction in (1.0, 0.9, 0.75, 0.6, 0.5)],
            axis=1,
        )
        per_scale_confidence = stacked.max(axis=2)
        best_scale = stacked[
            np.arange(stacked.shape[0]), per_scale_confidence.argmax(axis=1)
        ]
        confidence_weights = np.power(per_scale_confidence, 4)
        confidence_weights /= confidence_weights.sum(axis=1, keepdims=True)
        confidence_weighted = (stacked * confidence_weights[:, :, None]).sum(axis=1)
        sorted_probabilities = np.sort(stacked, axis=2)
        margins = sorted_probabilities[:, :, -1] - sorted_probabilities[:, :, -2]
        margin_weights = np.maximum(margins, 1e-6)
        margin_weights /= margin_weights.sum(axis=1, keepdims=True)
        margin_weighted = (stacked * margin_weights[:, :, None]).sum(axis=1)
        for name, mask in (
            ("adaptive_disagreement", disagreement),
            ("adaptive_confidence_080", low_080),
            ("adaptive_disagreement_or_confidence_080", disagreement | low_080),
            ("adaptive_disagreement_or_confidence_070", disagreement | low_070),
            ("adaptive_disagreement_or_confidence_085", disagreement | low_085),
            ("adaptive_disagreement_or_confidence_090", disagreement | low_090),
            ("adaptive_disagreement_or_confidence_095", disagreement | low_095),
        ):
            probability_parts[name].append(
                np.where(mask[:, None], multiscale, current)
            )
        for name, mask in (
            ("adaptive_disagreement_center_weighted", disagreement),
            (
                "adaptive_disagreement_or_confidence_080_center_weighted",
                disagreement | low_080,
            ),
            (
                "adaptive_disagreement_or_confidence_085_center_weighted",
                disagreement | low_085,
            ),
        ):
            probability_parts[name].append(
                np.where(mask[:, None], center_weighted, current)
            )
        adaptive_mask = disagreement | low_080
        for name, candidate in (
            ("adaptive_best_scale_080", best_scale),
            ("adaptive_confidence_weighted_080", confidence_weighted),
            ("adaptive_margin_weighted_080", margin_weighted),
        ):
            probability_parts[name].append(
                np.where(adaptive_mask[:, None], candidate, current)
            )

    y_true = np.concatenate(y_true_parts)
    report = {
        "samples": int(len(y_true)),
        "samples_per_class": args.samples_per_class,
        "strategies": {
            name: metrics(y_true, np.concatenate(parts))
            for name, parts in probability_parts.items()
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
