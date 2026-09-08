from __future__ import annotations

import argparse
import json
import platform
import shutil
import sys
from collections import Counter
from pathlib import Path

from .common import load_json, seed_everything, sha256_file, stable_hash, utc_now, validate_config, write_json
from .data import build_dataset, read_manifest


def train(config_path: Path, manifest_path: Path, data_root: Path, runs_dir: Path) -> Path:
    config = load_json(config_path)
    validate_config(config)
    seed = int(config["seed"])
    seed_everything(seed)
    try:
        import numpy as np
        import tensorflow as tf
    except ImportError as exc:
        raise RuntimeError("TensorFlow training dependencies are not installed; install ml/requirements.lock") from exc

    manifest_report_path = manifest_path.with_suffix(".report.json")
    if not manifest_report_path.is_file():
        raise FileNotFoundError("Manifest readiness report is required")
    manifest_report = load_json(manifest_report_path)
    if not manifest_report.get("scope_ready_for_training"):
        raise ValueError("Dataset does not meet the frozen class/OOD sample and group acceptance gates")
    train_rows = read_manifest(manifest_path, data_root, "train")
    validation_rows = read_manifest(manifest_path, data_root, "validation")
    if not train_rows or not validation_rows:
        raise ValueError("Both train and validation splits need approved, valid samples")
    if any(row["split"] == "test" for row in train_rows + validation_rows):
        raise AssertionError("Held-out test data entered training")
    labels = [item["id"] for item in config["classes"]]
    missing = set(labels) - {row["label"] for row in train_rows}
    if missing:
        raise ValueError(f"Training split has no samples for classes: {sorted(missing)}")

    dataset_version = sha256_file(manifest_path)
    experiment_id = f"{utc_now()[:10].replace('-', '')}T{utc_now()[11:19].replace(':', '')}Z-{stable_hash(dataset_version + json.dumps(config, sort_keys=True))[:10]}"
    run_dir = runs_dir / experiment_id
    if run_dir.exists():
        raise FileExistsError(run_dir)
    run_dir.mkdir(parents=True)
    shutil.copy2(config_path, run_dir / "config.json")
    shutil.copy2(manifest_path, run_dir / "manifest.csv")
    shutil.copy2(manifest_report_path, run_dir / "manifest.report.json")
    lock_path = Path(__file__).resolve().parents[2] / "requirements.lock"
    shutil.copy2(lock_path, run_dir / "requirements.lock")
    (run_dir / "labels.txt").write_text("\n".join(labels) + "\n", encoding="utf-8")
    write_json(run_dir / "provenance.json", {
        "schema_version": 1,
        "experiment_id": experiment_id,
        "started_at": utc_now(),
        "dataset_version": dataset_version,
        "config_sha256": sha256_file(config_path),
        "tensorflow": tf.__version__,
        "numpy": np.__version__,
        "python": sys.version,
        "platform": platform.platform(),
        "physical_devices": [f"{device.device_type}:{device.name}" for device in tf.config.list_physical_devices()],
        "requirements_lock_sha256": sha256_file(lock_path),
        "seed": seed,
        "data_root_at_training": data_root.resolve().as_posix(),
        "test_samples_read_during_training": 0,
    })

    image = config["image"]
    model_cfg = config["model"]
    batch_size = int(model_cfg["batch_size"])
    decoder = image.get("decoder", "pil")
    train_ds = build_dataset(train_rows, labels, image["height"], image["width"], batch_size, True, seed, decoder=decoder)
    val_ds = build_dataset(validation_rows, labels, image["height"], image["width"], batch_size, False, seed, decoder=decoder)
    if model_cfg["mixed_precision"] and tf.config.list_physical_devices("GPU"):
        tf.keras.mixed_precision.set_global_policy("mixed_float16")

    # Mimari yapılandırmadan gelir; sabit yazılırsa config'teki değer sessizce
    # yok sayılır ve provenance kaydı gerçekte eğitilenle uyuşmaz.
    architectures = {
        "MobileNetV3Small": tf.keras.applications.MobileNetV3Small,
        "MobileNetV3Large": tf.keras.applications.MobileNetV3Large,
        "EfficientNetB0": tf.keras.applications.EfficientNetB0,
    }
    architecture = str(model_cfg["architecture"])
    if architecture not in architectures:
        raise ValueError(f"Desteklenmeyen mimari: {architecture}")

    inputs = tf.keras.Input(shape=(image["height"], image["width"], 3), name="rgb_0_255")
    base_kwargs = {
        "input_shape": (image["height"], image["width"], 3),
        "include_top": False,
        "weights": "imagenet" if model_cfg["imagenet_weights"] else None,
        "pooling": "avg",
    }
    if architecture.startswith("MobileNetV3"):
        base_kwargs["alpha"] = float(model_cfg["alpha"])
        base_kwargs["include_preprocessing"] = bool(image["include_preprocessing"])
    base = architectures[architecture](**base_kwargs)
    base.trainable = False
    x = base(inputs, training=False)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(len(labels), activation="softmax", dtype="float32", name="probabilities")(x)
    model = tf.keras.Model(inputs, outputs, name=f"nutrisense_{architecture.lower()}")

    # Augmentation eğitim sırasında GPU'da çalışsın diye modeli sarmalar.
    # Ölçüm: tf.data içinde CPU'da çalışırken hat 2548 görsel/sn'den
    # 248'e düşüyordu. Sarmalanan model kaydedilmez; diske yazılan ve
    # TFLite'a giden model bu katmanları içermez.
    augmenter = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal", seed=seed),
        tf.keras.layers.RandomRotation(0.06, seed=seed + 1),
        tf.keras.layers.RandomZoom(0.12, seed=seed + 2),
        tf.keras.layers.RandomContrast(0.15, seed=seed + 3),
    ], name="train_only_augmentation")
    train_inputs = tf.keras.Input(shape=(image["height"], image["width"], 3), name="rgb_0_255")
    train_model = tf.keras.Model(
        train_inputs, model(augmenter(train_inputs)), name="nutrisense_training_wrapper"
    )
    train_model.compile(
        optimizer=tf.keras.optimizers.Adam(float(model_cfg["learning_rate_head"])),
        loss="sparse_categorical_crossentropy", metrics=["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(k=min(3, len(labels)), name="top3")],
    )
    class_counts = Counter(row["label"] for row in train_rows)
    class_weights = {index: len(train_rows) / (len(labels) * class_counts[label]) for index, label in enumerate(labels)}
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(run_dir / "best.keras", monitor="val_loss", save_best_only=True),
        tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=int(model_cfg["early_stopping_patience"]), restore_best_weights=True),
        tf.keras.callbacks.CSVLogger(run_dir / "training.csv"),
        tf.keras.callbacks.TerminateOnNaN(),
    ]
    head_history = train_model.fit(train_ds, validation_data=val_ds, epochs=int(model_cfg["head_epochs"]), callbacks=callbacks, class_weight=class_weights)

    base.trainable = True
    freeze_until = max(0, len(base.layers) - int(model_cfg["fine_tune_last_layers"]))
    for layer in base.layers[:freeze_until]:
        layer.trainable = False
    for layer in base.layers[freeze_until:]:
        if isinstance(layer, tf.keras.layers.BatchNormalization):
            layer.trainable = False
    train_model.compile(
        optimizer=tf.keras.optimizers.Adam(float(model_cfg["learning_rate_fine_tune"])),
        loss="sparse_categorical_crossentropy", metrics=["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(k=min(3, len(labels)), name="top3")],
    )
    fine_history = train_model.fit(train_ds, validation_data=val_ds, epochs=int(model_cfg["fine_tune_epochs"]), callbacks=callbacks, class_weight=class_weights)
    model.save(run_dir / "model.keras")
    write_json(run_dir / "history.json", {"head": head_history.history, "fine_tune": fine_history.history})
    try:
        import matplotlib.pyplot as plt

        combined = {
            key: list(head_history.history.get(key, [])) + list(fine_history.history.get(key, []))
            for key in set(head_history.history) | set(fine_history.history)
        }
        fig, axes = plt.subplots(1, 2, figsize=(12, 4))
        for key in ("loss", "val_loss"):
            if key in combined:
                axes[0].plot(combined[key], label=key)
        for key in ("accuracy", "val_accuracy"):
            if key in combined:
                axes[1].plot(combined[key], label=key)
        axes[0].set(title="Loss", xlabel="Epoch")
        axes[1].set(title="Accuracy", xlabel="Epoch")
        axes[0].legend()
        axes[1].legend()
        fig.tight_layout()
        fig.savefig(run_dir / "learning_curves.png", dpi=160)
        plt.close(fig)
    except ImportError:
        pass
    write_json(run_dir / "status.json", {
        "status": "trained_not_evaluated", "experiment_id": experiment_id,
        "model_sha256": sha256_file(run_dir / "model.keras"),
        "next_required_command": f"python -m nutrisense_ml.evaluate --run {run_dir.as_posix()} --data-root <DATA_ROOT> --split validation",
        "warning": "No test metric is valid until the separately sealed test evaluation is run.",
    })
    return run_dir


def main() -> None:
    parser = argparse.ArgumentParser(description="Train without reading the held-out test split")
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--runs-dir", type=Path, required=True)
    args = parser.parse_args()
    print(train(args.config, args.manifest, args.data_root, args.runs_dir))


if __name__ == "__main__":
    main()
