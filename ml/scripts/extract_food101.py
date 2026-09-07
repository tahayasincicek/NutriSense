"""Food-101 parquet parcalarini disk uzerinde sinif klasorlerine acar.

Kaynak: https://huggingface.co/datasets/ethz/food101 (ETH Zurich Food-101).
Lisans kapisi `sources/licenses.json` icindeki `food101_official` satiridir:
ticari olmayan akademik arastirma, atif zorunlu, yeniden dagitim yok.

Cikti: data/raw/<sinif>/f101_<idx>.jpg ve intake satirlari.
Var olan sinif klasorlerine dokunulmaz; yalnizca eksik olanlar yazilir.
"""

from __future__ import annotations

import argparse
import csv
import io
from pathlib import Path

import pyarrow.parquet as pq
from PIL import Image

SOURCE_ID = "food101_official"


def load_label_names(shard: Path) -> list[str]:
    """Sinif adlarini parquet sema meta verisinden okur."""
    schema = pq.read_schema(shard)
    field = schema.field("label")
    if field.type.num_fields if hasattr(field.type, "num_fields") else 0:
        pass
    # HuggingFace ClassLabel adlari sema meta verisinde JSON olarak durur.
    import json

    meta = schema.metadata or {}
    for key, value in meta.items():
        if b"huggingface" in key.lower():
            info = json.loads(value.decode("utf-8"))
            features = info.get("info", {}).get("features", {})
            label = features.get("label", {})
            names = label.get("names")
            if names:
                return list(names)
    raise SystemExit("Sinif adlari parquet meta verisinde bulunamadi")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shards", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--intake", required=True, type=Path)
    parser.add_argument("--per-class", type=int, default=750)
    parser.add_argument("--skip-existing", action="store_true")
    args = parser.parse_args()

    shards = sorted(args.shards.glob("*.parquet"))
    if not shards:
        raise SystemExit(f"Parquet bulunamadi: {args.shards}")
    names = load_label_names(shards[0])
    print(f"sinif sayisi: {len(names)}")

    existing = {d.name for d in args.out.iterdir() if d.is_dir()} if args.out.exists() else set()
    written = {name: 0 for name in names}
    rows: list[dict[str, str]] = []

    for shard in shards:
        table = pq.read_table(shard, columns=["image", "label"])
        images = table.column("image").to_pylist()
        labels = table.column("label").to_pylist()
        for blob, label_id in zip(images, labels):
            name = names[label_id]
            if args.skip_existing and name in existing:
                continue
            if written[name] >= args.per_class:
                continue
            target_dir = args.out / name
            target_dir.mkdir(parents=True, exist_ok=True)
            index = written[name]
            path = target_dir / f"f101_{index:05d}.jpg"
            if not path.exists():
                raw = blob["bytes"] if isinstance(blob, dict) else blob
                with Image.open(io.BytesIO(raw)) as opened:
                    opened.convert("RGB").save(path, "JPEG", quality=92)
            written[name] = index + 1
            rows.append({
                "path": f"{name}/{path.name}",
                "label": name,
                "source_id": SOURCE_ID,
                "license_id": SOURCE_ID,
                # Her gorsel kendi grubudur: Food-101'de ayni cekimden
                # turemis kopya bilgisi yok, grup birlestirmesi manifest
                # asamasindaki dhash ile yapilir.
                "group_id": f"f101_{name}_{index:05d}",
                "split_hint": "",
            })
        done = sum(1 for name in names if written[name] >= args.per_class)
        print(f"{shard.name}: {len(rows)} satir, {done}/{len(names)} sinif doldu")

    args.intake.parent.mkdir(parents=True, exist_ok=True)
    with args.intake.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["path", "label", "source_id", "license_id", "group_id", "split_hint"],
        )
        writer.writeheader()
        writer.writerows(rows)
    print(f"yazilan gorsel: {len(rows)} -> {args.intake}")


if __name__ == "__main__":
    main()
