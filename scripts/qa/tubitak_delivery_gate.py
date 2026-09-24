"""Verify external TÜBİTAK delivery evidence without inventing results."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
REQUIRED_VOICEOVER_SCENARIOS = {
    "first_launch_consent",
    "registration_login",
    "camera_permission_denied",
    "gallery_analysis",
    "food_confirmation",
    "history_and_undo",
    "dietitian_sharing",
    "tts_stt_interruption",
    "large_text_dark_theme",
}


@dataclass(frozen=True)
class Check:
    key: str
    passed: bool
    detail: str


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        raise ValueError(f"dosya bulunamadı: {path.relative_to(ROOT)}") from None
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"geçersiz JSON: {path.relative_to(ROOT)} ({exc.msg})"
        ) from None
    if not isinstance(value, dict):
        raise ValueError(f"JSON nesnesi bekleniyor: {path.relative_to(ROOT)}")
    return value


def _parse_iso_date(value: object) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return True


def check_field_analysis(path: Path) -> Check:
    try:
        manifest = _read_json(path)
    except ValueError as exc:
        return Check("real_field_analysis", False, str(exc))
    passed = (
        manifest.get("status") == "REAL_DATA_ANALYZED"
        and manifest.get("synthetic") is False
        and manifest.get("tables_generated") is True
        and manifest.get("figures_generated") is True
        and bool(manifest.get("results"))
    )
    if passed:
        return Check(
            "real_field_analysis",
            True,
            f"gerçek veri analizi: {manifest.get('analysis_run_id', 'run-id yok')}",
        )
    return Check(
        "real_field_analysis",
        False,
        "onamlı katılımcı verisiyle REAL_DATA_ANALYZED manifesti gerekli; "
        f"mevcut durum: {manifest.get('status', 'bilinmiyor')}",
    )


def check_voiceover(path: Path) -> Check:
    try:
        record = _read_json(path)
    except ValueError as exc:
        return Check("physical_iphone_voiceover", False, str(exc))
    scenarios = record.get("scenarios")
    scenarios = scenarios if isinstance(scenarios, list) else []
    results = {
        str(item.get("id")): item.get("result")
        for item in scenarios
        if isinstance(item, dict)
    }
    missing = sorted(
        scenario
        for scenario in REQUIRED_VOICEOVER_SCENARIOS
        if results.get(scenario) != "pass"
    )
    evidence = record.get("evidence_files")
    evidence = evidence if isinstance(evidence, list) else []
    existing_evidence = [
        item
        for item in evidence
        if isinstance(item, str) and (ROOT / item).is_file()
    ]
    metadata_ok = all(
        isinstance(record.get(key), str) and record[key].strip()
        for key in ("device_model", "ios_version", "app_revision")
    ) and _parse_iso_date(record.get("tested_at"))
    passed = metadata_ok and not missing and bool(existing_evidence)
    if passed:
        return Check(
            "physical_iphone_voiceover",
            True,
            f"{record['device_model']} / iOS {record['ios_version']}; "
            f"{len(existing_evidence)} kanıt dosyası",
        )
    reasons: list[str] = []
    if not metadata_ok:
        reasons.append("cihaz/iOS/revision/tarih metadata'sı eksik")
    if missing:
        reasons.append("geçmeyen senaryolar: " + ", ".join(missing))
    if not existing_evidence:
        reasons.append("depo içinde kanıt dosyası yok")
    return Check("physical_iphone_voiceover", False, "; ".join(reasons))


def check_dissemination(path: Path) -> Check:
    try:
        record = _read_json(path)
    except ValueError as exc:
        return Check("dissemination", False, str(exc))
    events = record.get("events")
    events = events if isinstance(events, list) else []
    accepted: list[dict[str, Any]] = []
    for event in events:
        if not isinstance(event, dict):
            continue
        has_reference = bool(event.get("public_url")) or (
            isinstance(event.get("evidence_file"), str)
            and (ROOT / event["evidence_file"]).is_file()
        )
        if (
            event.get("status") in {"presented", "published"}
            and all(event.get(key) for key in ("title", "venue"))
            and _parse_iso_date(event.get("date"))
            and has_reference
        ):
            accepted.append(event)
    if accepted:
        return Check(
            "dissemination",
            True,
            f"kanıtlı yaygınlaştırma etkinliği: {len(accepted)}",
        )
    return Check(
        "dissemination",
        False,
        "sunulmuş/yayımlanmış etkinlik ve URL veya kanıt dosyası gerekli",
    )


def run(root: Path = ROOT) -> list[Check]:
    return [
        check_field_analysis(root / "analysis" / "results_manifest.json"),
        check_voiceover(root / "delivery_evidence" / "voiceover_acceptance.json"),
        check_dissemination(root / "delivery_evidence" / "dissemination.json"),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="SMS hariç dış TÜBİTAK teslim kanıtlarını doğrular."
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    checks = run()
    passed = all(item.passed for item in checks)
    if args.json:
        print(
            json.dumps(
                {
                    "status": "PASS" if passed else "BLOCKED",
                    "sms_checked": False,
                    "checks": [item.__dict__ for item in checks],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        for item in checks:
            marker = "PASS" if item.passed else "BLOCKED"
            print(f"[{marker}] {item.key}: {item.detail}")
        print(f"TUBITAK_DELIVERY_WITHOUT_SMS={'PASS' if passed else 'BLOCKED'}")
    return 0 if passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
