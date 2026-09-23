"""Build a high-precision train-only set from scored and visually reviewed candidates."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from collections import Counter
from pathlib import Path

from PIL import Image, ImageOps


def dhash(path: Path, size: int = 8) -> str:
    with Image.open(path) as opened:
        image = ImageOps.exif_transpose(opened).convert("L").resize((size + 1, size))
    pixels = list(image.getdata())
    bits = 0
    for row in range(size):
        for column in range(size):
            left = pixels[row * (size + 1) + column]
            right = pixels[row * (size + 1) + column + 1]
            bits = (bits << 1) | int(left > right)
    return f"{bits:016x}"


def distance(first: str, second: str) -> int:
    return (int(first, 16) ^ int(second, 16)).bit_count()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", type=Path, nargs="+", required=True)
    parser.add_argument("--scores", type=Path, required=True)
    parser.add_argument("--sheet-index", type=Path, required=True)
    parser.add_argument("--manual-review", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--min-probability", type=float, default=0.10)
    parser.add_argument("--max-rank", type=int, default=3)
    parser.add_argument("--near-duplicate-distance", type=int, default=3)
    args = parser.parse_args()

    scores = json.loads(args.scores.read_text(encoding="utf-8"))
    score_by_path = {str(Path(row["local_path"])): row for row in scores}
    sheet_index = json.loads(args.sheet_index.read_text(encoding="utf-8"))
    manual = json.loads(args.manual_review.read_text(encoding="utf-8"))
    manual_labels = set(manual["accepted_sorted_indexes"])
    manual_paths: set[str] = set()
    for label, indexes in manual["accepted_sorted_indexes"].items():
        by_index = {int(row["index"]): str(Path(row["path"])) for row in sheet_index[label]}
        manual_paths.update(by_index[index] for index in indexes)

    all_rows: list[tuple[Path, dict]] = []
    for root in args.candidates:
        for row in json.loads((root / "attribution.json").read_text(encoding="utf-8")):
            path = root / row["local_path"]
            if path.is_file():
                normalized = dict(row)
                normalized.setdefault("description_url", normalized.get("source_url", ""))
                normalized.setdefault("artist", normalized.get("creator", ""))
                normalized["candidate_root"] = root.as_posix()
                normalized["candidate_path"] = path.as_posix()
                all_rows.append((path, normalized))

    args.output.mkdir(parents=True, exist_ok=True)
    accepted_hashes: set[str] = set()
    accepted_dhashes: dict[str, list[str]] = {}
    counts: Counter[str] = Counter()
    reviewed: list[dict] = []

    for path, row in sorted(all_rows, key=lambda item: (item[1]["label"], item[0].as_posix())):
        label = str(row["label"])
        score = score_by_path.get(str(path))
        if label in manual_labels:
            accepted = str(path) in manual_paths
            reason = "accepted_manual_visual_review" if accepted else "rejected_manual_visual_review"
        else:
            accepted = bool(
                score
                and int(score["expected_rank"]) <= args.max_rank
                and float(score["expected_probability"]) >= args.min_probability
            )
            reason = "accepted_model_assisted_review" if accepted else "rejected_low_label_consistency"

        if accepted:
            try:
                image_hash = str(row["sha256"])
                image_dhash = dhash(path)
            except OSError:
                accepted = False
                reason = "rejected_unreadable_image"
            else:
                if image_hash in accepted_hashes:
                    accepted = False
                    reason = "rejected_exact_duplicate"
                elif any(
                    distance(image_dhash, previous) <= args.near_duplicate_distance
                    for previous in accepted_dhashes.get(label, [])
                ):
                    accepted = False
                    reason = "rejected_near_duplicate"
                else:
                    accepted_hashes.add(image_hash)
                    accepted_dhashes.setdefault(label, []).append(image_dhash)

        reviewed_row = dict(row)
        reviewed_row["review_status"] = "accepted_train_only" if accepted else "rejected_visual_or_consistency_review"
        reviewed_row["review_reason"] = reason
        if score:
            reviewed_row["baseline_expected_probability"] = score["expected_probability"]
            reviewed_row["baseline_expected_rank"] = score["expected_rank"]
        reviewed.append(reviewed_row)
        if not accepted:
            continue

        destination = args.output / label / f"{path.parent.parent.name}_{path.name}"
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
        counts[label] += 1

    report = {
        "schema_version": 1,
        "policy": "manual review for ambiguous/critical classes; conservative model-assisted review elsewhere; train-only",
        "min_probability": args.min_probability,
        "max_rank": args.max_rank,
        "near_duplicate_distance": args.near_duplicate_distance,
        "candidate_total": len(reviewed),
        "accepted_total": sum(counts.values()),
        "accepted_by_label": dict(sorted(counts.items())),
        "rejected_total": len(reviewed) - sum(counts.values()),
        "rows": reviewed,
    }
    (args.output / "curation_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({key: value for key, value in report.items() if key != "rows"}, indent=2))


if __name__ == "__main__":
    main()
