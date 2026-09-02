"""TürkSofrası-25 parquet paylarından görselleri JPEG olarak çıkarır.

Kaynak: https://huggingface.co/datasets/yunusserhat/TurkishFoods-25
Lisans: Apache-2.0 — eğitim ve türev çalışma serbest, atıf gerekir.

Çıktı hattın beklediği `data/raw/<label>/<dosya>.jpg` düzenindedir ve
`data/intake_tr.csv` giriş listesini üretir.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import pyarrow.parquet as pq

SOURCE_ID = "turkishfoods25"
LICENSE_ID = "turkishfoods25"


def label_names(shard: Path) -> list[str]:
    metadata = pq.ParquetFile(shard).schema_arrow.metadata or {}
    for raw in metadata.values():
        text = raw.decode("utf-8", errors="ignore")
        if '"names"' not in text:
            continue
        payload = json.loads(text)
        features = payload.get("info", payload).get("features", {})
        return features["label"]["names"]
    raise RuntimeError("Parquet metadata does not carry the label names")


def extract(parquet_dir: Path, out_root: Path, intake_path: Path, per_class: int) -> None:
    shards = sorted(parquet_dir.glob("*.parquet"))
    if not shards:
        raise SystemExit(f"No parquet shards under {parquet_dir}")
    names = label_names(shards[0])

    kept: dict[str, int] = {name: 0 for name in names}
    rows: list[dict[str, str]] = []
    counter = 0

    for shard in shards:
        parquet = pq.ParquetFile(shard)
        for batch in parquet.iter_batches(batch_size=256, columns=["image", "label"]):
            images = batch.column("image").to_pylist()
            labels = batch.column("label").to_pylist()
            for image, label_index in zip(images, labels):
                name = names[label_index]
                if kept[name] >= per_class:
                    continue
                payload = image.get("bytes")
                if not payload:
                    continue
                counter += 1
                stem = Path(image.get("path") or f"tf25-{counter}").stem
                stem = "".join(c for c in stem if c.isalnum() or c in "_-")[:50]
                relative = f"{name}/tf25_{stem}_{counter}.jpg"
                destination = out_root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(payload)
                rows.append({
                    "path": relative,
                    "label": name,
                    "source_id": SOURCE_ID,
                    "license_id": LICENSE_ID,
                    # Her görsel ayrı bir tabaktır; gruplama görsel kimliğidir.
                    "group_id": f"tf25-{counter}",
                    "split_hint": "",
                })
                kept[name] += 1

    intake_path.parent.mkdir(parents=True, exist_ok=True)
    with intake_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["path", "label", "source_id", "license_id", "group_id", "split_hint"],
        )
        writer.writeheader()
        writer.writerows(rows)

    for name, count in sorted(kept.items()):
        print(f"{name}: {count}")
    print(f"toplam satir: {len(rows)} -> {intake_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--parquet-dir", type=Path, default=Path("data/tr_parquet"))
    parser.add_argument("--out-root", type=Path, default=Path("data/raw"))
    parser.add_argument("--intake", type=Path, default=Path("data/intake_tr.csv"))
    parser.add_argument("--per-class", type=int, default=100000)
    args = parser.parse_args()
    extract(args.parquet_dir, args.out_root, args.intake, args.per_class)


if __name__ == "__main__":
    main()
