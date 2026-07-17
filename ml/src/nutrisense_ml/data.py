from __future__ import annotations

import csv
from pathlib import Path
from typing import Any


def read_manifest(path: Path, data_root: Path, split: str | None = None, include_ood: bool = False) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    rows = [row for row in rows if row["status"] == "ok"]
    if split is not None:
        rows = [row for row in rows if row["split"] == split]
    if not include_ood:
        rows = [row for row in rows if row["is_ood"] != "true"]
    root = data_root.resolve()
    for row in rows:
        resolved = (root / row["path"]).resolve()
        try:
            resolved.relative_to(root)
        except ValueError as exc:
            raise ValueError(f"Manifest path escapes data root: {row['path']}") from exc
        row["path"] = resolved.as_posix()
    return rows


def center_crop_resize(path: str, height: int, width: int):
    import numpy as np
    import tensorflow as tf
    from PIL import Image, ImageOps

    def decode(value):
        resolved = Path(value.numpy().decode("utf-8"))
        with Image.open(resolved) as opened:
            rgb = ImageOps.exif_transpose(opened).convert("RGB")
            fitted = ImageOps.fit(rgb, (width, height), method=Image.Resampling.BILINEAR, centering=(0.5, 0.5))
            return np.asarray(fitted, dtype=np.float32)

    image = tf.numpy_function(decode, [path], Tout=tf.float32)
    image.set_shape([height, width, 3])
    return image


def build_dataset(rows, labels: list[str], height: int, width: int, batch_size: int, training: bool, seed: int):
    import tensorflow as tf

    label_to_index = {label: index for index, label in enumerate(labels)}
    paths = [row["path"] for row in rows]
    indices = [label_to_index[row["label"]] for row in rows]
    ds = tf.data.Dataset.from_tensor_slices((paths, indices))
    if training:
        ds = ds.shuffle(len(rows), seed=seed, reshuffle_each_iteration=True)

    augmenter = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal", seed=seed),
        tf.keras.layers.RandomRotation(0.06, seed=seed + 1),
        tf.keras.layers.RandomZoom(0.12, seed=seed + 2),
        tf.keras.layers.RandomContrast(0.15, seed=seed + 3),
    ], name="train_only_augmentation")

    def load(path, label):
        image = center_crop_resize(path, height, width)
        if training:
            image = augmenter(image, training=True)
        return image, label

    options = tf.data.Options()
    options.experimental_deterministic = True
    return ds.map(load, num_parallel_calls=tf.data.AUTOTUNE, deterministic=True).batch(batch_size).with_options(options).prefetch(tf.data.AUTOTUNE)
