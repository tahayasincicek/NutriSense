from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score, recall_score

from nutrisense_ml.data import build_dataset, read_manifest


def _metrics(y_true: np.ndarray, probabilities: np.ndarray) -> dict[str, float]:
    predicted = probabilities.argmax(axis=1)
    return {
        "accuracy": float(accuracy_score(y_true, predicted)),
        "macro_f1": float(f1_score(y_true, predicted, average="macro", zero_division=0)),
        "macro_recall": float(
            recall_score(y_true, predicted, average="macro", zero_division=0)
        ),
    }


def _blur(images: tf.Tensor) -> tf.Tensor:
    kernel_2d = tf.constant(
        [[1.0, 2.0, 1.0], [2.0, 4.0, 2.0], [1.0, 2.0, 1.0]],
        dtype=tf.float32,
    ) / 16.0
    kernel = tf.tile(kernel_2d[:, :, None, None], [1, 1, 3, 1])
    return tf.nn.depthwise_conv2d(images, kernel, strides=[1, 1, 1, 1], padding="SAME")


def _zoom_out(images: tf.Tensor, size: int = 176) -> tf.Tensor:
    resized = tf.image.resize(images, [size, size], antialias=True)
    return tf.image.resize_with_crop_or_pad(resized, 224, 224)


def _jpeg(images: tf.Tensor, quality: int = 45) -> tf.Tensor:
    images = tf.cast(tf.clip_by_value(images, 0.0, 255.0), tf.uint8)
    return tf.map_fn(
        lambda image: tf.cast(
            tf.io.decode_jpeg(tf.io.encode_jpeg(image, quality=quality), channels=3),
            tf.float32,
        ),
        images,
        fn_output_signature=tf.TensorSpec([224, 224, 3], tf.float32),
    )


def _variants(images: tf.Tensor) -> dict[str, tf.Tensor]:
    images = tf.cast(images, tf.float32)
    zoomed = _zoom_out(images)
    return {
        "clean": images,
        "low_light": tf.clip_by_value(images * 0.55 + 8.0, 0.0, 255.0),
        "soft_blur": _blur(images),
        "zoom_out": zoomed,
        "jpeg_q45": _jpeg(images),
        "warm_color": tf.clip_by_value(
            images * tf.constant([1.10, 0.98, 0.86], tf.float32), 0.0, 255.0
        ),
        "combined": tf.clip_by_value(_blur(zoomed) * 0.65 + 6.0, 0.0, 255.0),
    }


def _four_view(model: tf.keras.Model, images: tf.Tensor) -> np.ndarray:
    original = model(images, training=False)
    flipped = model(tf.image.flip_left_right(images), training=False)
    crop = tf.image.resize(tf.image.central_crop(images, 0.90), [224, 224], antialias=True)
    cropped = model(crop, training=False)
    crop_flipped = model(tf.image.flip_left_right(crop), training=False)
    return ((original + flipped + cropped + crop_flipped) / 4.0).numpy()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Measure device-independent camera robustness on a non-test split."
    )
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--split", choices=("validation", "test"), default="validation")
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument(
        "--samples-per-class",
        type=int,
        default=20,
        help="Deterministic balanced subset size; use 0 for the complete split.",
    )
    args = parser.parse_args()

    labels = [
        line.strip()
        for line in args.labels.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    rows = read_manifest(args.manifest, args.data_root, args.split)
    if args.samples_per_class > 0:
        rng = np.random.default_rng(42)
        balanced_rows = []
        for label in labels:
            indices = np.array(
                [index for index, row in enumerate(rows) if row["label"] == label]
            )
            rng.shuffle(indices)
            balanced_rows.extend(rows[index] for index in indices[: args.samples_per_class])
        rows = balanced_rows
    dataset = build_dataset(
        rows, labels, 224, 224, args.batch_size, False, 42, decoder="native_prefitted"
    )
    model = tf.keras.models.load_model(args.model, compile=False)
    truth: list[np.ndarray] = []
    predictions: dict[str, list[np.ndarray]] = {}
    for images, target in dataset:
        truth.append(target.numpy())
        for name, variant in _variants(images).items():
            predictions.setdefault(name, []).append(_four_view(model, variant))

    y_true = np.concatenate(truth)
    results = {
        name: _metrics(y_true, np.concatenate(parts))
        for name, parts in predictions.items()
    }
    robust_names = [name for name in results if name != "clean"]
    results["robust_mean"] = {
        metric: float(np.mean([results[name][metric] for name in robust_names]))
        for metric in ("accuracy", "macro_f1", "macro_recall")
    }
    print(
        json.dumps(
            {"split": args.split, "samples": len(y_true), "results": results},
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
