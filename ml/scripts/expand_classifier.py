"""Expand a trained softmax head while preserving all existing class weights."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--old-labels", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--output-labels", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=2209)
    args = parser.parse_args()

    tf.keras.utils.set_random_seed(args.seed)
    old_labels = args.old_labels.read_text(encoding="utf-8").splitlines()
    config = json.loads(args.config.read_text(encoding="utf-8"))
    new_labels = [entry["id"] for entry in config["classes"]]
    if not set(old_labels).issubset(new_labels):
        raise ValueError("Every old label must remain in the expanded config")
    if len(new_labels) != len(set(new_labels)):
        raise ValueError("Expanded labels contain duplicates")

    old_model = tf.keras.models.load_model(args.model)
    if old_model.output_shape[-1] != len(old_labels):
        raise ValueError("Old label count does not match model output")
    base = next(
        layer for layer in old_model.layers if isinstance(layer, tf.keras.Model)
    )
    old_dense = old_model.layers[-1]
    old_dropout = old_model.layers[-2]

    inputs = tf.keras.Input(shape=old_model.input_shape[1:], name="rgb_0_255")
    x = base(inputs, training=False)
    x = tf.keras.layers.Dropout(float(old_dropout.rate), name="dropout")(x)
    outputs = tf.keras.layers.Dense(
        len(new_labels), activation="softmax", dtype="float32", name="probabilities"
    )(x)
    model = tf.keras.Model(inputs, outputs, name=old_model.name)

    old_kernel, old_bias = old_dense.get_weights()
    kernel, bias = model.layers[-1].get_weights()
    old_index = {label: index for index, label in enumerate(old_labels)}
    for new_position, label in enumerate(new_labels):
        if label not in old_index:
            continue
        position = old_index[label]
        kernel[:, new_position] = old_kernel[:, position]
        bias[new_position] = old_bias[position]
    model.layers[-1].set_weights(
        [kernel.astype(np.float32), bias.astype(np.float32)]
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    model.save(args.output)
    args.output_labels.write_text("\n".join(new_labels) + "\n", encoding="utf-8")
    print(f"expanded {len(old_labels)} -> {len(new_labels)} classes: {args.output}")


if __name__ == "__main__":
    main()
