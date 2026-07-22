import json
from pathlib import Path

import pandas as pd
import pytest
from PIL import Image

from analysis.tools.generate_synthetic_fixture import write_fixture
from nutrisense_analysis.pipeline import (
    DataQualityError,
    _load_export,
    run_pipeline,
    validate_usability,
    write_no_real_data_status,
)


def test_missing_real_exports_produce_status_without_results(tmp_path: Path):
    output = write_no_real_data_status(
        tmp_path / "outputs",
        "python analysis/run_analysis.py --mode real",
        [tmp_path / "missing-usability.json", tmp_path / "missing-survey.json"],
    )
    manifest = json.loads((output / "results_manifest.json").read_text(encoding="utf-8"))
    assert manifest["status"] == "NO REAL DATA"
    assert manifest["synthetic"] is False
    assert manifest["results"] == {}
    assert manifest["tables_generated"] is False
    assert not (output / "tables").exists()


def test_synthetic_run_is_watermarked_and_traceable(tmp_path: Path):
    usability, survey = write_fixture(tmp_path / "fixture", participant_count=6)
    output = run_pipeline(
        usability,
        survey,
        tmp_path / "outputs",
        "synthetic",
        "synthetic-test-command",
    )
    manifest = json.loads((output / "results_manifest.json").read_text(encoding="utf-8"))
    assert manifest["status"] == "SYNTHETIC_PIPELINE_TEST_ONLY"
    assert manifest["synthetic"] is True
    assert "primary.success" in manifest["results"]
    assert "primary.duration" in manifest["results"]

    for filename in (
        "condition_descriptives.csv",
        "primary_inference.csv",
        "task_descriptives.csv",
        "sensitivity_analysis.csv",
        "survey_likert.csv",
    ):
        table = pd.read_csv(output / "tables" / filename)
        assert set(table["synthetic"].astype(str).str.lower()) == {"true"}
        assert set(table["result_id"]).issubset(manifest["results"])
    figure_path = output / "figures" / "success_rate.png"
    assert figure_path.stat().st_size > 0
    with Image.open(figure_path) as figure:
        description = json.loads(figure.info["Description"])
    assert description["analysis_run_id"] == manifest["analysis_run_id"]
    assert description["data_checksum_sha256"] == manifest["inputs"][
        "combined_checksum_sha256"
    ]
    assert not (tmp_path / "outputs" / "results_manifest.json").exists()


def test_real_mode_rejects_synthetic_export(tmp_path: Path):
    usability, _ = write_fixture(tmp_path / "fixture", participant_count=2)
    with pytest.raises(DataQualityError, match="data_origin=participant"):
        validate_usability(_load_export(usability), "real")


def test_negative_duration_stops_pipeline(tmp_path: Path):
    usability, _ = write_fixture(tmp_path / "fixture", participant_count=2)
    payload = json.loads(usability.read_text(encoding="utf-8"))
    payload["rows"][0]["duration_seconds"] = -1
    usability.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(DataQualityError, match="negatif duration"):
        validate_usability(_load_export(usability), "synthetic")


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        ("duplicate", "duplicate participant/task/condition"),
        ("impossible_success", "abort/failed ile birlikte success=true"),
        ("missing_task", "eksik görev-koşul"),
    ],
)
def test_structural_quality_failures_stop_analysis(
    tmp_path: Path, mutation: str, message: str
):
    usability, _ = write_fixture(tmp_path / mutation, participant_count=2)
    payload = json.loads(usability.read_text(encoding="utf-8"))
    if mutation == "duplicate":
        payload["rows"].append(dict(payload["rows"][0]))
    elif mutation == "impossible_success":
        payload["rows"][0]["success"] = True
        payload["rows"][0]["status"] = "failed"
        payload["rows"][0]["abort_reason"] = "synthetic_abort"
    else:
        payload["rows"].pop(0)
    usability.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(DataQualityError, match=message):
        validate_usability(_load_export(usability), "synthetic")


def test_open_text_pii_is_redacted(tmp_path: Path):
    usability, survey = write_fixture(tmp_path / "fixture", participant_count=2)
    payload = json.loads(survey.read_text(encoding="utf-8"))
    open_row = next(row for row in payload["rows"] if row["question_id"] == "q6")
    open_row["answer"] = "Bana test@example.com veya +90 555 111 22 33 üzerinden ulaşın"
    survey.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    output = run_pipeline(
        usability,
        survey,
        tmp_path / "outputs",
        "synthetic",
        "pii-redaction-test",
    )
    redacted = (output / "tables" / "qualitative_redacted.csv").read_text(
        encoding="utf-8"
    )
    assert "test@example.com" not in redacted
    assert "555 111" not in redacted
    assert "[EMAIL_REDACTED]" in redacted
    assert "[PHONE_REDACTED]" in redacted


def test_reproduction_notebook_is_clean_and_calls_canonical_cli():
    notebook_path = Path(__file__).resolve().parents[1] / "notebooks" / "reproduce.ipynb"
    notebook = json.loads(notebook_path.read_text(encoding="utf-8"))
    code_cells = [cell for cell in notebook["cells"] if cell["cell_type"] == "code"]
    assert code_cells
    assert all(cell["execution_count"] is None for cell in code_cells)
    assert all(cell["outputs"] == [] for cell in code_cells)
    source = "\n".join("".join(cell["source"]) for cell in code_cells)
    assert "analysis' / 'run_analysis.py" in source
