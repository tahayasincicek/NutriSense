"""Score candidate-label consistency with the accepted baseline model.

Scores are review aids, not ground truth. Low-scoring images must be inspected;
they are not silently discarded because difficult valid examples are valuable.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--candidates", type=Path, nargs="+", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=64)
    args = parser.parse_args()

    import tensorflow as tf
    # Import registers the custom serialized layer used by the accepted model.
    from nutrisense_ml.augmentation import RandomApply  # noqa: F401

    labels = [line.strip() for line in args.labels.read_text(encoding="utf-8").splitlines() if line.strip()]
    label_to_index = {label: index for index, label in enumerate(labels)}
    model = tf.keras.models.load_model(args.model)
    items: list[dict] = []
    for root in args.candidates:
        rows = json.loads((root / "attribution.json").read_text(encoding="utf-8"))
        for row in rows:
            label = str(row["label"])
            path = root / row["local_path"]
            if label in label_to_index and path.is_file():
                items.append({"root": root.as_posix(), "path": path, "row": row})

    output_rows: list[dict] = []
    for start in range(0, len(items), args.batch_size):
        batch_items = items[start : start + args.batch_size]
        arrays: list[np.ndarray] = []
        valid: list[dict] = []
        for item in batch_items:
            try:
                with Image.open(item["path"]) as opened:
                    image = ImageOps.exif_transpose(opened).convert("RGB")
                    image = ImageOps.fit(image, (224, 224), method=Image.Resampling.BILINEAR)
                arrays.append(np.asarray(image, dtype=np.float32))
                valid.append(item)
            except OSError:
                continue
        if not arrays:
            continue
        probabilities = np.asarray(model.predict(np.stack(arrays), verbose=0))
        for item, probs in zip(valid, probabilities, strict=True):
            expected = str(item["row"]["label"])
            expected_index = label_to_index[expected]
            order = np.argsort(probs)[::-1]
            rank = int(np.where(order == expected_index)[0][0]) + 1
            top5 = [
                {"label": labels[int(index)], "probability": float(probs[index])}
                for index in order[:5]
            ]
            output_rows.append(
                {
                    "label": expected,
                    "local_path": item["path"].as_posix(),
                    "source_root": item["root"],
                    "sha256": item["row"]["sha256"],
                    "expected_probability": float(probs[expected_index]),
                    "expected_rank": rank,
                    "top5": top5,
                }
            )
        print(f"{min(start + args.batch_size, len(items))}/{len(items)}", flush=True)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"scored": len(output_rows), "labels": len({row['label'] for row in output_rows})}))


if __name__ == "__main__":
    main()
