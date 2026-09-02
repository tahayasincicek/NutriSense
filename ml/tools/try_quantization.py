"""Kuantizasyon seçeneklerini ölçer ve hangisinin dağıtılabilir olduğunu söyler.

Tam tamsayı (full integer) kuantizasyon MobileNetV3'te ağır bozulma üretiyor.
Bu betik alternatifleri aynı protokolle karşılaştırır: dinamik aralık ve
float16. Ölçüt ham olasılık farkı değil, kararın değişip değişmediğidir —
argmax uyumu ve doğruluk.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import tensorflow as tf

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from nutrisense_ml.data import center_crop_resize, read_manifest  # noqa: E402

RUN = Path("runs/20260902T061831Z-3a32310432")
ROOT = Path("data/raw")
SAMPLE_COUNT = 300


def image_of(path) -> np.ndarray:
    return center_crop_resize(tf.constant(str(path)), 224, 224).numpy()[None, ...]


def build(model, mode: str, representative) -> bytes:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if mode == "dynamic_range":
        # Ağırlıklar int8, aktivasyonlar float: kalibrasyon gerektirmez ve
        # hard-swish katmanlarını bozmaz.
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
    elif mode == "float16":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    elif mode == "full_integer":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
    else:
        raise ValueError(mode)
    return converter.convert()


def score(blob: bytes, rows, labels, model) -> dict:
    interpreter = tf.lite.Interpreter(model_content=blob)
    interpreter.allocate_tensors()
    input_info = interpreter.get_input_details()[0]
    output_info = interpreter.get_output_details()[0]
    label_index = {label: index for index, label in enumerate(labels)}

    agree = keras_correct = lite_correct = 0
    differences = []
    for row in rows:
        x = image_of(row["path"])
        keras_output = model.predict(x, verbose=0)

        value = x
        if input_info["dtype"] == np.uint8:
            scale, zero = input_info["quantization"]
            value = np.clip(np.rint(x / scale + zero), 0, 255).astype(np.uint8)
        interpreter.set_tensor(input_info["index"], value.astype(input_info["dtype"]))
        interpreter.invoke()
        raw = interpreter.get_tensor(output_info["index"])
        if output_info["dtype"] == np.uint8:
            out_scale, out_zero = output_info["quantization"]
            raw = (raw.astype(np.float32) - out_zero) * out_scale

        differences.append(float(np.max(np.abs(keras_output - raw))))
        agree += int(keras_output.argmax() == raw.argmax())
        truth = label_index[row["label"]]
        keras_correct += int(keras_output.argmax() == truth)
        lite_correct += int(raw.argmax() == truth)

    total = len(rows)
    return {
        "bytes": len(blob),
        "argmax_agreement": agree / total,
        "keras_accuracy": keras_correct / total,
        "lite_accuracy": lite_correct / total,
        "max_abs_difference": max(differences),
        "median_abs_difference": float(np.median(differences)),
    }


def main() -> None:
    labels = (RUN / "labels.txt").read_text(encoding="utf-8").split()
    rows = read_manifest(RUN / "manifest.csv", ROOT, "validation")[:SAMPLE_COUNT]
    model = tf.keras.models.load_model(RUN / "model.keras")

    def representative():
        for row in rows[:100]:
            yield [image_of(row["path"])]

    for mode in ("dynamic_range", "float16", "full_integer"):
        try:
            blob = build(model, mode, representative)
            result = score(blob, rows, labels, model)
        except Exception as error:  # noqa: BLE001 - rapor amaçlı
            print(f"{mode}: DONUSTURULEMEDI ({type(error).__name__})")
            continue
        print(
            f"{mode}: boyut={result['bytes'] / 1e6:.2f}MB "
            f"argmax_uyum={result['argmax_agreement']:.4f} "
            f"keras_dogruluk={result['keras_accuracy']:.4f} "
            f"lite_dogruluk={result['lite_accuracy']:.4f} "
            f"maks_fark={result['max_abs_difference']:.4f} "
            f"medyan_fark={result['median_abs_difference']:.4f}"
        )


if __name__ == "__main__":
    main()
