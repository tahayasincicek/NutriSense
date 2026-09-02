from __future__ import annotations

import argparse
from pathlib import Path

from .common import load_json, sha256_file, utc_now, write_json
from .data import build_dataset, read_manifest


def expected_calibration_error(y_true, probabilities, bins: int = 15) -> float:
    import numpy as np

    confidence = probabilities.max(axis=1)
    predicted = probabilities.argmax(axis=1)
    correct = predicted == y_true
    result = 0.0
    edges = np.linspace(0.0, 1.0, bins + 1)
    for low, high in zip(edges[:-1], edges[1:]):
        mask = (confidence > low) & (confidence <= high)
        if mask.any():
            result += float(mask.mean() * abs(correct[mask].mean() - confidence[mask].mean()))
    return result


def select_threshold(supported_true, supported_probabilities, ood_probabilities, min_coverage: float, max_error: float):
    import numpy as np

    candidates = np.unique(np.concatenate([np.linspace(0.5, 0.99, 100), supported_probabilities.max(axis=1)]))
    best = None
    for threshold in candidates:
        supported_conf = supported_probabilities.max(axis=1)
        accepted = supported_conf >= threshold
        coverage = float(accepted.mean())
        wrong_supported = int(((supported_probabilities.argmax(axis=1) != supported_true) & accepted).sum())
        ood_accepted = int((ood_probabilities.max(axis=1) >= threshold).sum()) if len(ood_probabilities) else 0
        accepted_total = int(accepted.sum()) + ood_accepted
        selective_error = (wrong_supported + ood_accepted) / accepted_total if accepted_total else 0.0
        if coverage >= min_coverage and selective_error <= max_error:
            candidate = {"threshold": float(threshold), "coverage": coverage, "selective_error": float(selective_error), "ood_false_accepts": ood_accepted}
            if best is None or candidate["coverage"] > best["coverage"]:
                best = candidate
    return best


def _predict(model, rows, labels, config):
    import numpy as np

    if not rows:
        return np.empty((0, len(labels)), dtype=np.float32)
    # Etiketler burada atılır; OOD satırları sınıf listesinde yer almadığı için
    # eşleşmeyen etikete izin verilir.
    ds = build_dataset(
        rows,
        labels,
        config["image"]["height"],
        config["image"]["width"],
        int(config["model"]["batch_size"]),
        False,
        int(config["seed"]),
        allow_unknown_labels=True,
    )
    images = ds.map(lambda image, _: image)
    return model.predict(images, verbose=0)


def evaluate(run_dir: Path, data_root: Path, split: str) -> dict:
    if split not in {"validation", "test"}:
        raise ValueError("Only validation or test evaluation is allowed")
    test_started = run_dir / "TEST_EVALUATION_STARTED.seal"
    if split == "test":
        if not (run_dir / "decision.json").exists():
            raise RuntimeError("Run validation first; a test threshold may not be selected from test data")
        try:
            with test_started.open("x", encoding="utf-8") as handle:
                handle.write(f"started_at={utc_now()}\n")
        except FileExistsError as exc:
            raise RuntimeError("Held-out test was already opened for this experiment; create a new experiment rather than reusing test feedback") from exc
    try:
        import matplotlib.pyplot as plt
        import numpy as np
        import tensorflow as tf
        from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score, top_k_accuracy_score
    except ImportError as exc:
        raise RuntimeError("Evaluation dependencies are not installed") from exc
    config = load_json(run_dir / "config.json")
    labels = (run_dir / "labels.txt").read_text(encoding="utf-8").splitlines()
    rows = read_manifest(run_dir / "manifest.csv", data_root, split, include_ood=True)
    supported = [row for row in rows if row["is_ood"] != "true"]
    ood = [row for row in rows if row["is_ood"] == "true"]
    if not supported:
        raise ValueError(f"No supported samples in {split}")
    label_to_index = {label: index for index, label in enumerate(labels)}
    y_true = np.array([label_to_index[row["label"]] for row in supported])
    model = tf.keras.models.load_model(run_dir / "model.keras")
    probabilities = _predict(model, supported, labels, config)
    ood_probabilities = _predict(model, ood, labels, config)
    predicted = probabilities.argmax(axis=1)
    top_k = min(3, len(labels))
    report = {
        "schema_version": 1, "status": "evaluated", "split": split,
        "evaluated_at": utc_now(), "experiment_id": run_dir.name,
        "dataset_version": sha256_file(run_dir / "manifest.csv"),
        "samples": len(supported), "ood_samples": len(ood),
        "accuracy": float(accuracy_score(y_true, predicted)),
        "macro_f1": float(f1_score(y_true, predicted, average="macro", zero_division=0)),
        "top_k": top_k,
        "top_k_accuracy": float(top_k_accuracy_score(y_true, probabilities, k=top_k, labels=list(range(len(labels))))),
        "ece_15_bins": expected_calibration_error(y_true, probabilities),
        "per_class": classification_report(y_true, predicted, labels=list(range(len(labels))), target_names=labels, output_dict=True, zero_division=0),
        "confusion_matrix": confusion_matrix(y_true, predicted, labels=list(range(len(labels)))).tolist(),
        "model_size_bytes": (run_dir / "model.keras").stat().st_size,
        "target_device_latency_ms": None,
        "target_device_latency_status": "not_run; must be measured on named physical Android/iOS hardware",
    }
    if split == "validation":
        decision = select_threshold(
            y_true, probabilities, ood_probabilities,
            float(config["decision"]["min_coverage"]), float(config["decision"]["max_selective_error"]),
        )
        report["decision"] = decision
        if decision is None:
            report["deployment_status"] = "blocked: validation cannot meet safety constraints"
        else:
            report["deployment_status"] = "threshold_selected_on_validation; test remains sealed"
            write_json(run_dir / "decision.json", {**decision, "selected_on": "validation", "experiment_id": run_dir.name})
    else:
        decision = load_json(run_dir / "decision.json")
        confidence = probabilities.max(axis=1)
        accepted = confidence >= decision["threshold"]
        wrong = (predicted != y_true) & accepted
        ood_false_accepts = int((ood_probabilities.max(axis=1) >= decision["threshold"]).sum()) if len(ood_probabilities) else 0
        report["decision"] = {
            "threshold_fixed_from_validation": decision["threshold"],
            "coverage": float(accepted.mean()),
            "selective_error": float((wrong.sum() + ood_false_accepts) / (accepted.sum() + ood_false_accepts)) if accepted.sum() + ood_false_accepts else 0.0,
            "ood_false_accepts": ood_false_accepts,
        }

    write_json(run_dir / f"metrics_{split}.json", report)
    matrix = np.array(report["confusion_matrix"])
    fig, axis = plt.subplots(figsize=(10, 8))
    image = axis.imshow(matrix, cmap="Blues")
    axis.set(xticks=range(len(labels)), yticks=range(len(labels)), xticklabels=labels, yticklabels=labels, xlabel="Predicted", ylabel="True")
    plt.setp(axis.get_xticklabels(), rotation=45, ha="right")
    fig.colorbar(image, ax=axis)
    fig.tight_layout()
    fig.savefig(run_dir / f"confusion_matrix_{split}.png", dpi=160)
    plt.close(fig)
    confidence = probabilities.max(axis=1)
    correct = predicted == y_true
    edges = np.linspace(0.0, 1.0, 16)
    bin_confidence, bin_accuracy = [], []
    for low, high in zip(edges[:-1], edges[1:]):
        mask = (confidence > low) & (confidence <= high)
        if mask.any():
            bin_confidence.append(float(confidence[mask].mean()))
            bin_accuracy.append(float(correct[mask].mean()))
    fig, axis = plt.subplots(figsize=(6, 6))
    axis.plot([0, 1], [0, 1], "--", color="gray", label="perfect calibration")
    axis.plot(bin_confidence, bin_accuracy, marker="o", label="model")
    axis.set(xlim=(0, 1), ylim=(0, 1), xlabel="Mean confidence", ylabel="Observed accuracy", title=f"Calibration ({split})")
    axis.legend()
    fig.tight_layout()
    fig.savefig(run_dir / f"calibration_{split}.png", dpi=160)
    plt.close(fig)
    if split == "test":
        (run_dir / "TEST_EVALUATED.seal").write_text(f"evaluated_at={utc_now()}\nmetrics_sha256={sha256_file(run_dir / 'metrics_test.json')}\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate validation or one-time held-out test data")
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--split", choices=["validation", "test"], required=True)
    args = parser.parse_args()
    print(evaluate(args.run, args.data_root, args.split))


if __name__ == "__main__":
    main()
