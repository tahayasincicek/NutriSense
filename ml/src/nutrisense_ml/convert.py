from __future__ import annotations

import argparse
import json
import shutil
import time
from pathlib import Path

from .common import load_json, sha256_file, utc_now, write_json
from .data import center_crop_resize, read_manifest


def _require(path: Path, message: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"{message}: {path}")


def _images(rows, config, count: int):
    import numpy as np

    selected = rows[:count]
    for row in selected:
        tensor = center_crop_resize(row["path"], config["image"]["height"], config["image"]["width"])
        yield np.expand_dims(tensor.numpy().astype(np.float32), 0)


def _invoke(interpreter, input_value):
    import numpy as np

    input_info = interpreter.get_input_details()[0]
    output_info = interpreter.get_output_details()[0]
    value = input_value
    if input_info["dtype"] == np.uint8:
        scale, zero = input_info["quantization"]
        if scale <= 0:
            raise RuntimeError("INT8 model has invalid input quantization parameters")
        value = np.clip(np.rint(value / scale + zero), 0, 255).astype(np.uint8)
    interpreter.set_tensor(input_info["index"], value.astype(input_info["dtype"]))
    interpreter.invoke()
    output = interpreter.get_tensor(output_info["index"])
    if output_info["dtype"] == np.uint8:
        scale, zero = output_info["quantization"]
        output = (output.astype(np.float32) - zero) * scale
    return output


def convert(run_dir: Path, data_root: Path, output_dir: Path, formats: list[str], samples: int = 100) -> dict:
    model_path = run_dir / "model.keras"
    _require(model_path, "A real trained Keras model is required; demo fallback is forbidden")
    _require(run_dir / "decision.json", "Validation-selected rejection threshold is required before deployment conversion")
    _require(run_dir / "manifest.csv", "Training manifest is required")
    _require(run_dir / "labels.txt", "Label order is required")
    try:
        import numpy as np
        import tensorflow as tf
    except ImportError as exc:
        raise RuntimeError("TensorFlow conversion dependencies are not installed") from exc
    config = load_json(run_dir / "config.json")
    calibration_rows = read_manifest(run_dir / "manifest.csv", data_root, "train")
    equivalence_rows = read_manifest(run_dir / "manifest.csv", data_root, "validation")
    if not calibration_rows:
        raise ValueError("INT8 conversion requires real approved training samples; random calibration is forbidden")
    if not equivalence_rows:
        raise ValueError("TFLite equivalence needs real validation samples")
    output_dir.mkdir(parents=True, exist_ok=True)
    # Model karışık hassasiyetle eğitildiğinde katmanlar float16 politikası
    # taşır ve TFLite dönüştürücü bu grafiği reddeder. Dönüşüm her zaman
    # float32 politikası altında yapılır; ağırlıklar aynıdır, yalnız hesap
    # tipi sabitlenir.
    # Dönüşüm CPU'da yapılır. TFLite yorumlayıcısı da CPU'da koştuğu için
    # denklik karşılaştırması ancak böyle biçim farkını ölçer; GPU'da koşan
    # Keras'la kıyaslamak donanım farkını ölçer (0,0015'e karşı 0,000002).
    tf.config.set_visible_devices([], "GPU")
    tf.keras.mixed_precision.set_global_policy("float32")
    model = tf.keras.models.load_model(model_path)

    def _force_float32(node):
        """Yapılandırmadaki float16 politikalarını özyinelemeli olarak temizler.

        Politika iç içe alt modellerin katmanlarında da durduğu için tek tek
        `model.layers` üzerinden gezmek yetmez.
        """
        if isinstance(node, dict):
            if "dtype" in node:
                dtype = node["dtype"]
                if isinstance(dtype, str) and "float16" in dtype:
                    node["dtype"] = "float32"
                elif isinstance(dtype, dict):
                    name = dtype.get("config", {}).get("name", "")
                    if "float16" in str(name):
                        node["dtype"] = "float32"
            return {key: _force_float32(value) for key, value in node.items()}
        if isinstance(node, list):
            return [_force_float32(item) for item in node]
        return node

    config_dict = json.loads(json.dumps(model.get_config()))
    if "float16" in json.dumps(config_dict):
        weights = model.get_weights()
        model = model.__class__.from_config(_force_float32(config_dict))
        model.set_weights(weights)
    report = {
        "schema_version": 1, "status": "converted", "experiment_id": run_dir.name,
        "converted_at": utc_now(), "keras_sha256": sha256_file(model_path), "formats": {},
        "warning": "Desktop timing is not target-device latency evidence.",
    }

    def representative():
        for image in _images(calibration_rows, config, samples):
            yield [image]

    for format_name in formats:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        tolerance = 1e-4
        if format_name == "float32":
            converter.optimizations = []
        elif format_name == "float16":
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            converter.target_spec.supported_types = [tf.float16]
            # float16 mantisi ~3 ondalık basamak taşır; softmax çıkışında
            # 0,03'e varan sapma bu biçimin normal davranışıdır. Kararın
            # değişmediğini argmax kapısı ayrıca garanti eder.
            tolerance = 0.05
        elif format_name == "int8":
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            converter.representative_dataset = representative
            converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
            converter.inference_input_type = tf.uint8
            converter.inference_output_type = tf.uint8
            tolerance = 0.08
        else:
            raise ValueError(f"Unsupported format: {format_name}")
        data = converter.convert()
        path = output_dir / f"nutrisense_{format_name}.tflite"
        path.write_bytes(data)
        # Varsayılan XNNPACK delegesi kapatılır: INT8 grafiğinde hazırlanamıyor
        # ve denklik ölçümü hızlandırıcının değil biçimin farkını görmeli.
        interpreter = tf.lite.Interpreter(
            model_path=str(path),
            experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_WITHOUT_DEFAULT_DELEGATES,
        )
        interpreter.allocate_tensors()
        differences, matches, timings = [], 0, []
        keras_correct = 0
        lite_correct = 0
        label_to_index = {label: index for index, label in enumerate((run_dir / "labels.txt").read_text(encoding="utf-8").splitlines())}
        checked = list(_images(equivalence_rows, config, min(samples, 50)))
        for index, image in enumerate(checked):
            keras_output = model.predict(image, verbose=0)
            started = time.perf_counter()
            lite_output = _invoke(interpreter, image)
            timings.append((time.perf_counter() - started) * 1000)
            differences.append(float(np.max(np.abs(keras_output - lite_output))))
            matches += int(keras_output.argmax() == lite_output.argmax())
            true_index = label_to_index[equivalence_rows[index]["label"]]
            keras_correct += int(keras_output.argmax() == true_index)
            lite_correct += int(lite_output.argmax() == true_index)
        maximum = max(differences)
        match_rate = matches / len(checked)
        # Kullanıcıya ulaşan şey olasılığın kendisi değil, seçilen sınıftır.
        # Bu yüzden asıl kapı argmax uyumudur: tek bir örnekte bile karar
        # değişiyorsa biçim dağıtılamaz. Ham olasılık farkı ikinci kapıdır ve
        # sayısal biçimin beklenen hassasiyetine göre ayarlanır.
        if match_rate < 1.0:
            path.unlink(missing_ok=True)
            raise RuntimeError(
                f"{format_name} equivalence failed: argmax_match_rate={match_rate:.4f} < 1.0"
            )
        if maximum > tolerance:
            path.unlink(missing_ok=True)
            raise RuntimeError(f"{format_name} equivalence failed: max_abs_difference={maximum:.6f} > {tolerance}")
        input_info = interpreter.get_input_details()[0]
        output_info = interpreter.get_output_details()[0]
        report["formats"][format_name] = {
            "path": path.as_posix(), "bytes": path.stat().st_size, "sha256": sha256_file(path),
            "equivalence_samples": len(checked), "max_abs_difference": maximum,
            "argmax_match_rate": matches / len(checked), "tolerance": tolerance,
            "desktop_median_inference_ms": float(np.median(timings)),
            "input_dtype": str(input_info["dtype"]), "input_shape": input_info["shape"].tolist(),
            "input_quantization": list(input_info["quantization"]),
            "output_dtype": str(output_info["dtype"]), "output_quantization": list(output_info["quantization"]),
            "validation_subset_keras_accuracy": keras_correct / len(checked),
            "validation_subset_tflite_accuracy": lite_correct / len(checked),
            "validation_subset_accuracy_delta": (lite_correct - keras_correct) / len(checked),
            "held_out_test_accuracy_delta": None,
            "held_out_test_accuracy_delta_status": "not_run; evaluate a predeclared deployment candidate without tuning on test",
        }
    shutil.copy2(run_dir / "labels.txt", output_dir / "labels.txt")
    preprocessing_source = Path(__file__).resolve().parents[2] / "contracts" / "preprocessing.json"
    shutil.copy2(preprocessing_source, output_dir / "preprocessing.json")
    shutil.copy2(run_dir / "decision.json", output_dir / "decision.json")
    report["labels_sha256"] = sha256_file(output_dir / "labels.txt")
    report["preprocessing_sha256"] = sha256_file(output_dir / "preprocessing.json")
    write_json(output_dir / "conversion_report.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert a real trained model and verify Keras/TFLite equivalence")
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--formats", nargs="+", choices=["float32", "float16", "int8"], default=["float32", "int8"])
    parser.add_argument("--samples", type=int, default=100)
    args = parser.parse_args()
    print(json.dumps(convert(args.run, args.data_root, args.output, args.formats, args.samples), indent=2))


if __name__ == "__main__":
    main()
