"""Food-101 parquet paylarından yalnız kapsamdaki sınıfları JPEG olarak çıkarır.

Hattın beklediği `data/raw/<label>/<dosya>.jpg` düzenini ve `data/intake.csv`
giriş listesini üretir. Kapsam dışı sınıflardan da OOD örneği toplanır; bunlar
altıncı bir yemek sınıfı olarak değil, "desteklenmeyen" kovası olarak kullanılır.

Bu betik eğitim ortamının parçası değildir; `requirements.lock` dışında
pyarrow gerektirir ve ayrı bir sanal ortamda çalıştırılır.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from pathlib import Path

import pyarrow.parquet as pq

SCOPE = {
    "baklava": 2,
    "hamburger": 53,
    "pizza": 76,
    "omelette": 67,
    "french_fries": 40,
}
OOD_LABEL = "__ood__"
SOURCE_ID = "food101_official"
LICENSE_ID = "food101_official"


def label_names(sample_shard: Path) -> list[str]:
    metadata = pq.ParquetFile(sample_shard).schema_arrow.metadata or {}
    for raw in metadata.values():
        text = raw.decode("utf-8", errors="ignore")
        if '"names"' not in text:
            continue
        payload = json.loads(text)
        features = payload.get("info", payload).get("features", {})
        return features["label"]["names"]
    raise RuntimeError("Parquet metadata does not carry the label names")


def extract(
    parquet_dir: Path,
    out_root: Path,
    intake_path: Path,
    per_class: int,
    ood_total: int,
    seed: int,
) -> None:
    shards = sorted(parquet_dir.glob("*.parquet"))
    if not shards:
        raise SystemExit(f"No parquet shards under {parquet_dir}")
    names = label_names(shards[0])
    wanted = {index: name for name, index in SCOPE.items()}
    ood_pool_indices = [i for i in range(len(names)) if i not in wanted]

    rng = random.Random(seed)
    kept: dict[str, int] = {name: 0 for name in SCOPE}
    ood_kept = 0
    rows: list[dict[str, str]] = []

    for shard in shards:
        parquet = pq.ParquetFile(shard)
        for batch in parquet.iter_batches(batch_size=256, columns=["image", "label"]):
            images = batch.column("image").to_pylist()
            labels = batch.column("label").to_pylist()
            for image, label_index in zip(images, labels):
                if label_index in wanted:
                    name = wanted[label_index]
                    if kept[name] >= per_class:
                        continue
                    target_label = name
                elif ood_kept < ood_total and label_index in ood_pool_indices:
                    # OOD havuzu tek bir sınıfa yığılmasın diye seyrekleştirilir.
                    if rng.random() > 0.02:
                        continue
                    target_label = OOD_LABEL
                else:
                    continue

                payload = image["bytes"]
                if not payload:
                    continue
                stem = Path(image["path"] or f"{label_index}-{len(rows)}").stem
                relative = f"{target_label}/{stem}.jpg"
                destination = out_root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(payload)

                rows.append({
                    "path": relative,
                    "label": target_label,
                    "source_id": SOURCE_ID,
                    "license_id": LICENSE_ID,
                    # Food-101'de her görsel ayrı bir tabaktır; sızıntıya karşı
                    # gruplama görsel kimliğidir.
                    "group_id": stem,
                    "split_hint": "",
                })
                if target_label == OOD_LABEL:
                    ood_kept += 1
                else:
                    kept[target_label] += 1

        if all(count >= per_class for count in kept.values()) and ood_kept >= ood_total:
            break

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
    print(f"{OOD_LABEL}: {ood_kept}")
    print(f"toplam satir: {len(rows)} -> {intake_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--parquet-dir", type=Path, default=Path("data/parquet"))
    parser.add_argument("--out-root", type=Path, default=Path("data/raw"))
    parser.add_argument("--intake", type=Path, default=Path("data/intake.csv"))
    parser.add_argument("--per-class", type=int, default=1000)
    parser.add_argument("--ood-total", type=int, default=600)
    parser.add_argument("--seed", type=int, default=2209)
    args = parser.parse_args()
    extract(
        args.parquet_dir,
        args.out_root,
        args.intake,
        args.per_class,
        args.ood_total,
        args.seed,
    )


if __name__ == "__main__":
    main()
