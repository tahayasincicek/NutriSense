"""Create deterministic contact sheets for visual label-quality review."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--labels", nargs="+", required=True)
    parser.add_argument("--count", type=int, default=40)
    parser.add_argument(
        "--split", choices=("train", "validation"), default="train"
    )
    args = parser.parse_args()
    with args.manifest.open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))
    args.output.mkdir(parents=True, exist_ok=True)
    width, height, columns = 180, 155, 8
    for label in args.labels:
        eligible = [
            row
            for row in rows
            if row["label"] == label
            and row["split"] == args.split
            and row["status"] == "ok"
        ]
        selected = sorted(
            eligible,
            key=lambda row: hashlib.sha256(row["sample_id"].encode()).hexdigest(),
        )[: args.count]
        sheet_rows = (len(selected) + columns - 1) // columns
        canvas = Image.new(
            "RGB", (width * columns, height * sheet_rows), "white"
        )
        draw = ImageDraw.Draw(canvas)
        for index, row in enumerate(selected, start=1):
            image = Image.open(args.data_root / row["path"]).convert("RGB")
            image = ImageOps.fit(image, (width - 8, height - 28))
            x = ((index - 1) % columns) * width + 4
            y = ((index - 1) // columns) * height + 24
            canvas.paste(image, (x, y))
            draw.text(
                (x, 4 + ((index - 1) // columns) * height),
                f"{index} {Path(row['path']).name[:10]}",
                fill="black",
            )
        canvas.save(args.output / f"{label}.jpg", quality=90)
        print(label, len(eligible))


if __name__ == "__main__":
    main()
