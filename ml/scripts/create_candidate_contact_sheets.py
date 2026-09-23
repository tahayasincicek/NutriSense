"""Create deterministic review sheets from one or more candidate directories."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", type=Path, nargs="+", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--per-label", type=int, default=40)
    args = parser.parse_args()

    rows_by_label: dict[str, list[tuple[Path, str]]] = defaultdict(list)
    for root in args.candidates:
        rows = json.loads((root / "attribution.json").read_text(encoding="utf-8"))
        source_name = root.name
        for row in rows:
            path = root / row["local_path"]
            if path.is_file():
                rows_by_label[str(row["label"])].append((path, source_name))

    args.output.mkdir(parents=True, exist_ok=True)
    tile_w, tile_h, columns = 180, 155, 8
    index: dict[str, list[dict[str, str | int]]] = {}
    for label, entries in sorted(rows_by_label.items()):
        selected = sorted(entries, key=lambda item: (item[1], item[0].name))[: args.per_label]
        sheet_rows = max(1, (len(selected) + columns - 1) // columns)
        canvas = Image.new("RGB", (tile_w * columns, tile_h * sheet_rows), "white")
        draw = ImageDraw.Draw(canvas)
        sheet_index: list[dict[str, str | int]] = []
        for number, (path, source_name) in enumerate(selected, start=1):
            try:
                with Image.open(path) as opened:
                    image = ImageOps.exif_transpose(opened).convert("RGB")
                    image = ImageOps.fit(image, (tile_w - 8, tile_h - 30))
            except OSError:
                continue
            x = ((number - 1) % columns) * tile_w + 4
            y = ((number - 1) // columns) * tile_h
            canvas.paste(image, (x, y + 24))
            draw.text((x, y + 4), f"{number} {source_name[:8]}", fill="black")
            sheet_index.append(
                {"index": number, "source": source_name, "path": path.as_posix()}
            )
        canvas.save(args.output / f"{label}.jpg", quality=92)
        index[label] = sheet_index

    (args.output / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"labels": len(index), "candidates": sum(map(len, index.values()))}))


if __name__ == "__main__":
    main()
