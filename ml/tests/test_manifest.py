import csv
import json
from pathlib import Path

import pytest
from PIL import Image

from nutrisense_ml.manifest import build_manifest


def _write_intake(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["path", "label", "source_id", "license_id", "group_id", "split_hint"])
        writer.writeheader()
        writer.writerows(rows)


def _fixture_config(path: Path) -> None:
    path.write_text(json.dumps({
        "scope_id": "test", "seed": 2209,
        "splits": {"train": 0.5, "validation": 0.25, "test": 0.25},
        "classes": [{"id": "a"}, {"id": "b"}],
        "ood": {"label": "__ood__"},
        "decision": {"default_threshold_before_validation": None},
    }), encoding="utf-8")


def _licenses(path: Path) -> None:
    path.write_text(json.dumps({"sources": [{"id": "synthetic_test_only", "allowed_for_training": False}]}), encoding="utf-8")


def test_group_and_duplicate_never_cross_splits(tmp_path: Path) -> None:
    data = tmp_path / "data"
    data.mkdir()
    rows = []
    for label, color in (("a", "red"), ("b", "blue")):
        for group_index in range(4):
            name = f"{label}-{group_index}.png"
            Image.new("RGB", (24 + group_index, 24), color=color).save(data / name)
            rows.append({"path": name, "label": label, "source_id": "fixture", "license_id": "synthetic_test_only", "group_id": f"{label}-g{group_index}", "split_hint": ""})
    Image.open(data / "a-0.png").save(data / "a-copy.png")
    rows.append({"path": "a-copy.png", "label": "a", "source_id": "fixture", "license_id": "synthetic_test_only", "group_id": "a-copy-group", "split_hint": ""})
    intake, config, licenses, output = tmp_path / "intake.csv", tmp_path / "config.json", tmp_path / "licenses.json", tmp_path / "manifest.csv"
    _write_intake(intake, rows)
    _fixture_config(config)
    _licenses(licenses)
    report = build_manifest(intake, data, config, licenses, output, allow_test_fixtures=True)
    assert report["exact_or_near_duplicates"] >= 1
    with output.open(encoding="utf-8") as handle:
        manifest = list(csv.DictReader(handle))
    sample = next(row for row in manifest if row["path"].endswith("a-0.png"))
    copied = next(row for row in manifest if row["path"].endswith("a-copy.png"))
    assert sample["split"] == copied["split"]


def test_cross_label_duplicate_fails_closed(tmp_path: Path) -> None:
    data = tmp_path / "data"
    data.mkdir()
    Image.new("RGB", (16, 16), "green").save(data / "one.png")
    (data / "two.png").write_bytes((data / "one.png").read_bytes())
    rows = [
        {"path": "one.png", "label": "a", "source_id": "fixture", "license_id": "synthetic_test_only", "group_id": "one", "split_hint": ""},
        {"path": "two.png", "label": "b", "source_id": "fixture", "license_id": "synthetic_test_only", "group_id": "two", "split_hint": ""},
    ]
    intake, config, licenses, output = tmp_path / "intake.csv", tmp_path / "config.json", tmp_path / "licenses.json", tmp_path / "manifest.csv"
    _write_intake(intake, rows)
    _fixture_config(config)
    _licenses(licenses)
    with pytest.raises(ValueError, match="conflicting labels"):
        build_manifest(intake, data, config, licenses, output, allow_test_fixtures=True)


def test_unapproved_license_fails_without_private_test_switch(tmp_path: Path) -> None:
    data = tmp_path / "data"
    data.mkdir()
    Image.new("RGB", (16, 16), "red").save(data / "one.png")
    intake, config, licenses, output = tmp_path / "intake.csv", tmp_path / "config.json", tmp_path / "licenses.json", tmp_path / "manifest.csv"
    _write_intake(intake, [{"path": "one.png", "label": "a", "source_id": "fixture", "license_id": "synthetic_test_only", "group_id": "one", "split_hint": ""}])
    _fixture_config(config)
    _licenses(licenses)
    with pytest.raises(ValueError, match="not approved"):
        build_manifest(intake, data, config, licenses, output)
