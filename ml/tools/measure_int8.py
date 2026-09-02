"""INT8 dönüşümünün gerçekte ne kadar bozulduğunu ölçer.

Dönüşüm kapısı ham olasılık farkının maksimumuna bakar. Tek bir aykırı örnek
bu ölçüyü uçurabilir; kararın gerçekten değişip değişmediğini görmek için
argmax uyumu ve doğruluk ayrıca ölçülür. Bu betik kapıyı değiştirmez, yalnız
kanıt üretir.
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


def image_of(path) -> np.ndarray:
    return center_crop_resize(tf.constant(str(path)), 224, 224).numpy()[None, ...]


def main() -> None:
    labels = (RUN / "labels.txt").read_text(encoding="utf-8").split()
    rows = read_manifest(RUN / "manifest.csv", ROOT, "validation")[:300]
    model = tf.keras.models.load_model(RUN / "model.keras")

    def representative():
        for row in rows[:100]:
            yield [image_of(row["path"])]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.uint8
    converter.inference_output_type = tf.uint8
    blob = converter.convert()

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

        scale, zero = input_info["quantization"]
        quantized = np.clip(np.rint(x / scale + zero), 0, 255).astype(np.uint8)
        interpreter.set_tensor(input_info["index"], quantized)
        interpreter.invoke()
        raw = interpreter.get_tensor(output_info["index"])
        out_scale, out_zero = output_info["quantization"]
        lite_output = (raw.astype(np.float32) - out_zero) * out_scale

        differences.append(float(np.max(np.abs(keras_output - lite_output))))
        agree += int(keras_output.argmax() == lite_output.argmax())
        truth = label_index[row["label"]]
        keras_correct += int(keras_output.argmax() == truth)
        lite_correct += int(lite_output.argmax() == truth)

    total = len(rows)
    print(f"ornek={total}")
    print(f"argmax_uyum={agree / total:.4f}")
    print(f"keras_dogruluk={keras_correct / total:.4f}")
    print(f"int8_dogruluk={lite_correct / total:.4f}")
    print(f"maks_fark={max(differences):.4f}")
    print(f"ortalama_fark={float(np.mean(differences)):.4f}")
    print(f"medyan_fark={float(np.median(differences)):.4f}")
    print(f"fark_p95={float(np.percentile(differences, 95)):.4f}")


if __name__ == "__main__":
    main()
