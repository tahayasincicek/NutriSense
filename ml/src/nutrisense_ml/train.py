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


def train(
    config_path: Path,
    manifest_path: Path,
    data_root: Path,
    runs_dir: Path,
    warm_start_model: Path | None = None,
) -> Path:
    config = load_json(config_path)
    validate_config(config)
    seed = int(config["seed"])
    seed_everything(seed)
    try:
        import numpy as np
        import tensorflow as tf
        from .augmentation import RandomApply
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
    class_counts = Counter(row["label"] for row in train_rows)
    class_weights = {
        index: len(train_rows) / (len(labels) * class_counts[label])
        for index, label in enumerate(labels)
    }
    class_weights_by_label = {
        label: class_weights[index] for index, label in enumerate(labels)
    }

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
        "warm_start_model_sha256": (
            sha256_file(warm_start_model) if warm_start_model is not None else None
        ),
    })

    image = config["image"]
    model_cfg = config["model"]
    batch_size = int(model_cfg["batch_size"])
    decoder = image.get("decoder", "pil")
    source_sample_weights = {
        str(key): float(value)
        for key, value in model_cfg.get("source_sample_weights", {}).items()
    }
    label_sample_weight_multipliers = {
        str(key): float(value)
        for key, value in model_cfg.get("label_sample_weight_multipliers", {}).items()
    }
    unknown_weight_labels = set(label_sample_weight_multipliers) - set(labels)
    if unknown_weight_labels:
        raise ValueError(
            "label_sample_weight_multipliers contains unknown labels: "
            f"{sorted(unknown_weight_labels)}"
        )
    if any(value <= 0 for value in label_sample_weight_multipliers.values()):
        raise ValueError("label_sample_weight_multipliers values must be positive")
    effective_label_weights = {
        label: class_weights_by_label[label]
        * label_sample_weight_multipliers.get(label, 1.0)
        for label in labels
    }
    train_ds = build_dataset(
        train_rows,
        labels,
        image["height"],
        image["width"],
        batch_size,
        True,
        seed,
        decoder=decoder,
        sample_weight_by_source=source_sample_weights,
        sample_weight_by_label=(
            effective_label_weights
            if source_sample_weights or label_sample_weight_multipliers
            else None
        ),
    )
    val_ds = build_dataset(validation_rows, labels, image["height"], image["width"], batch_size, False, seed, decoder=decoder)
    if model_cfg["mixed_precision"] and tf.config.list_physical_devices("GPU"):
        tf.keras.mixed_precision.set_global_policy("mixed_float16")

    # Mimari yapılandırmadan gelir; sabit yazılırsa config'teki değer sessizce
    # yok sayılır ve provenance kaydı gerçekte eğitilenle uyuşmaz.
    architectures = {
        "MobileNetV3Small": tf.keras.applications.MobileNetV3Small,
        "MobileNetV3Large": tf.keras.applications.MobileNetV3Large,
        "EfficientNetB0": tf.keras.applications.EfficientNetB0,
        "EfficientNetV2B0": tf.keras.applications.EfficientNetV2B0,
    }
    architecture = str(model_cfg["architecture"])
    if architecture not in architectures:
        raise ValueError(f"Desteklenmeyen mimari: {architecture}")

    if warm_start_model is not None:
        model = tf.keras.models.load_model(warm_start_model)
        if model.output_shape[-1] != len(labels):
            raise ValueError("Warm-start model output does not match the configured labels")
        base = next(
            (layer for layer in model.layers if isinstance(layer, tf.keras.Model)),
            None,
        )
        if base is None:
            raise ValueError("Warm-start model does not contain a feature extractor")
    else:
        inputs = tf.keras.Input(
            shape=(image["height"], image["width"], 3), name="rgb_0_255"
        )
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
        x = tf.keras.layers.Dropout(float(model_cfg.get("dropout", 0.2)))(x)
        outputs = tf.keras.layers.Dense(
            len(labels), activation="softmax", dtype="float32", name="probabilities"
        )(x)
        model = tf.keras.Model(inputs, outputs, name=f"nutrisense_{architecture.lower()}")

    # Head eğitimi sırasında özellik çıkarıcı her iki başlangıç yolunda da
    # dondurulur. Genişletilmiş bir warm-start modelinin eski sınıf bilgisini
    # ilk epochlarda bozmasını önler.
    base.trainable = False

    # Augmentation eğitim sırasında GPU'da çalışsın diye modeli sarmalar.
    # Ölçüm: tf.data içinde CPU'da çalışırken hat 2548 görsel/sn'den
    # 248'e düşüyordu. Sarmalanan model kaydedilmez; diske yazılan ve
    # TFLite'a giden model bu katmanları içermez.
    aug_cfg = model_cfg.get("augmentation", {})
    augmentation_layers = [
        tf.keras.layers.RandomFlip("horizontal", seed=seed, dtype="float32"),
        tf.keras.layers.RandomRotation(float(aug_cfg.get("rotation", 0.06)), seed=seed + 1, dtype="float32"),
        tf.keras.layers.RandomZoom(float(aug_cfg.get("zoom", 0.12)), seed=seed + 2, dtype="float32"),
        tf.keras.layers.RandomContrast(float(aug_cfg.get("contrast", 0.15)), seed=seed + 3, dtype="float32"),
        tf.keras.layers.RandomTranslation(
            float(aug_cfg.get("translation_height", 0.0)),
            float(aug_cfg.get("translation_width", 0.0)),
            fill_mode="reflect",
            seed=seed + 4,
            dtype="float32",
        ),
        tf.keras.layers.RandomBrightness(
            float(aug_cfg.get("brightness", 0.0)),
            value_range=(0.0, 255.0),
            seed=seed + 5,
            dtype="float32",
        ),
    ]
    # Farklı telefon kameraları ve gerçek kullanımda nesne ölçeği, perspektif,
    # odak, renk işleme, ışık ve sensör gürültüsü değişir. Ürün modeline
    # eklenmeyen bu eğitim katmanları genel saha dağılımını taklit eder.
    field_cfg = aug_cfg.get("real_world_capture", {})
    if field_cfg.get("enabled", False):
        zoom_out = float(field_cfg.get("zoom_out", 0.35))
        field_layers = [
            tf.keras.layers.RandomZoom(
                height_factor=(0.0, zoom_out),
                width_factor=(0.0, zoom_out),
                fill_mode="constant",
                fill_value=0.0,
                seed=seed + 6,
                dtype="float32",
            ),
            tf.keras.layers.RandomPerspective(
                factor=float(field_cfg.get("perspective", 0.08)),
                scale=float(field_cfg.get("perspective_scale", 0.35)),
                fill_value=0.0,
                seed=seed + 7,
                dtype="float32",
            ),
            tf.keras.layers.RandomGaussianBlur(
                factor=float(field_cfg.get("blur_probability", 0.35)),
                kernel_size=3,
                sigma=(0.1, float(field_cfg.get("blur_sigma", 1.2))),
                seed=seed + 8,
                dtype="float32",
            ),
            tf.keras.layers.RandomSaturation(
                factor=float(field_cfg.get("saturation", 0.18)),
                seed=seed + 9,
                dtype="float32",
            ),
            tf.keras.layers.RandomHue(
                factor=float(field_cfg.get("hue", 0.04)),
                seed=seed + 10,
                dtype="float32",
            ),
            tf.keras.layers.GaussianNoise(
                stddev=float(field_cfg.get("sensor_noise", 0.8)),
                seed=seed + 11,
                dtype="float32",
            ),
        ]
        field_augmenter = tf.keras.Sequential(
            field_layers, name="field_capture_augmentation"
        )
        augmentation_layers.append(
            RandomApply(
                field_augmenter,
                probability=float(field_cfg.get("apply_probability", 1.0)),
                seed=seed + 12,
                name="random_field_capture_augmentation",
            )
        )
    augmenter = tf.keras.Sequential(
        augmentation_layers,
        name="train_only_augmentation",
    )
    train_inputs = tf.keras.Input(shape=(image["height"], image["width"], 3), name="rgb_0_255")
    train_model = tf.keras.Model(
        train_inputs, model(augmenter(train_inputs)), name="nutrisense_training_wrapper"
    )
    def optimizer(learning_rate):
        weight_decay = float(model_cfg.get("weight_decay", 0.0))
        if weight_decay > 0:
            return tf.keras.optimizers.AdamW(
                learning_rate=learning_rate,
                weight_decay=weight_decay,
                global_clipnorm=1.0,
            )
        return tf.keras.optimizers.Adam(learning_rate, global_clipnorm=1.0)

    train_model.compile(
        optimizer=optimizer(float(model_cfg["learning_rate_head"])),
        loss="sparse_categorical_crossentropy", metrics=["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(k=min(3, len(labels)), name="top3")],
    )
    fit_class_weights = (
        None
        if source_sample_weights or label_sample_weight_multipliers
        else class_weights
    )
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(run_dir / "best.keras", monitor="val_loss", save_best_only=True),
        tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=int(model_cfg["early_stopping_patience"]), restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.3,
            patience=max(2, int(model_cfg["early_stopping_patience"]) // 2),
            min_lr=float(model_cfg.get("minimum_learning_rate", 1e-7)),
        ),
        tf.keras.callbacks.CSVLogger(run_dir / "training.csv"),
        tf.keras.callbacks.TerminateOnNaN(),
    ]
    head_epochs = int(model_cfg["head_epochs"])
    head_history = None
    if head_epochs > 0:
        head_history = train_model.fit(
            train_ds,
            validation_data=val_ds,
            epochs=head_epochs,
            callbacks=callbacks,
            class_weight=fit_class_weights,
        )

    base.trainable = True
    freeze_until = max(0, len(base.layers) - int(model_cfg["fine_tune_last_layers"]))
    for layer in base.layers[:freeze_until]:
        layer.trainable = False
    for layer in base.layers[freeze_until:]:
        if isinstance(layer, tf.keras.layers.BatchNormalization):
            layer.trainable = False
    train_model.compile(
        optimizer=optimizer(float(model_cfg["learning_rate_fine_tune"])),
        loss="sparse_categorical_crossentropy", metrics=["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(k=min(3, len(labels)), name="top3")],
    )
    fine_history = train_model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=int(model_cfg["fine_tune_epochs"]),
        callbacks=callbacks,
        class_weight=fit_class_weights,
    )
    model.save(run_dir / "model.keras")
    write_json(
        run_dir / "history.json",
        {
            "head": head_history.history if head_history is not None else {},
            "fine_tune": fine_history.history,
        },
    )
    try:
        import matplotlib.pyplot as plt

        combined = {
            key: list(head_history.history.get(key, []) if head_history is not None else [])
            + list(fine_history.history.get(key, []))
            for key in (
                set(head_history.history if head_history is not None else {})
                | set(fine_history.history)
            )
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
    parser.add_argument("--warm-start-model", type=Path)
    args = parser.parse_args()
    print(
        train(
            args.config,
            args.manifest,
            args.data_root,
            args.runs_dir,
            args.warm_start_model,
        )
    )


if __name__ == "__main__":
    main()
