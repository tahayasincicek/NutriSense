import importlib.util
import json
from pathlib import Path
import sys


MODULE_PATH = Path(__file__).with_name("tubitak_delivery_gate.py")
SPEC = importlib.util.spec_from_file_location("tubitak_delivery_gate", MODULE_PATH)
assert SPEC and SPEC.loader
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)


def _write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")


def test_real_analysis_rejects_synthetic_or_empty_manifest(tmp_path):
    path = tmp_path / "manifest.json"
    _write(path, {"status": "SYNTHETIC_PIPELINE_TEST_ONLY", "synthetic": True})
    assert not gate.check_field_analysis(path).passed


def test_real_analysis_accepts_complete_real_manifest(tmp_path):
    path = tmp_path / "manifest.json"
    _write(path, {"status": "REAL_DATA_ANALYZED", "synthetic": False,
                  "tables_generated": True, "figures_generated": True,
                  "results": {"primary": {"value": 1}},
                  "analysis_run_id": "real-1"})
    assert gate.check_field_analysis(path).passed


def test_voiceover_requires_every_scenario_and_existing_evidence(tmp_path, monkeypatch):
    monkeypatch.setattr(gate, "ROOT", tmp_path)
    evidence = tmp_path / "delivery_evidence" / "files" / "proof.txt"
    evidence.parent.mkdir(parents=True)
    evidence.write_text("physical session note", encoding="utf-8")
    record = tmp_path / "voiceover.json"
    _write(record, {"device_model": "iPhone 13", "ios_version": "18.6",
                    "app_revision": "abcdef1", "tested_at": "2026-09-24",
                    "scenarios": [{"id": item, "result": "pass"}
                                  for item in gate.REQUIRED_VOICEOVER_SCENARIOS],
                    "evidence_files": ["delivery_evidence/files/proof.txt"]})
    assert gate.check_voiceover(record).passed


def test_dissemination_requires_completed_event_and_reference(tmp_path, monkeypatch):
    monkeypatch.setattr(gate, "ROOT", tmp_path)
    record = tmp_path / "dissemination.json"
    _write(record, {"events": [{"title": "NutriSense", "venue": "Project Day",
                                "date": "2026-09-24", "status": "presented",
                                "public_url": "https://example.org/evidence"}]})
    assert gate.check_dissemination(record).passed


def test_project_gate_accepts_labeled_method_completed_scenarios_and_documents(tmp_path):
    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "saha_calismasi_raporu.md").write_text(
        "yapay zekâ destekli, sabit `2209` tohumu; gerçek insan gözlemi değildir",
        encoding="utf-8",
    )
    rows = "\n".join(
        f"| {scenario} | beklenen | tamamlandı |"
        for scenario in gate.REQUIRED_VOICEOVER_SCENARIOS
    )
    (docs / "erisebilirlik_cihaz_kabul_kaydi.md").write_text(rows, encoding="utf-8")
    (docs / "yayginlastirma_paketi.md").write_text("y" * 500, encoding="utf-8")
    (docs / "tubitak_sonuc_raporu.md").write_text("r" * 2000, encoding="utf-8")

    checks = gate.run_project(tmp_path)

    assert all(check.passed for check in checks)


def test_project_gate_does_not_accept_unlabeled_human_claim(tmp_path):
    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "saha_calismasi_raporu.md").write_text(
        "Gerçek katılımcılarla tamamlandı.", encoding="utf-8"
    )

    assert not gate.check_project_field_method(
        docs / "saha_calismasi_raporu.md"
    ).passed
