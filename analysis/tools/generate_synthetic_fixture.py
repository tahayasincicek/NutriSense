"""Generate deterministic pipeline-test data. Never use as scientific evidence."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID


TASKS = [f"t{index}" for index in range(1, 7)]
CONDITIONS = ("nutrisense", "standardized_assistance")


def _participant(index: int) -> str:
    return str(UUID(int=index + 1))


def build_fixture(participant_count: int = 8) -> tuple[dict, dict]:
    usability_rows = []
    survey_rows = []
    base = datetime(2026, 1, 1, 9, 0, tzinfo=timezone.utc)
    for participant_index in range(participant_count):
        participant_id = _participant(participant_index)
        session_id = str(UUID(int=1000 + participant_index))
        sequence = "AB" if participant_index % 2 == 0 else "BA"
        for condition_index, condition in enumerate(CONDITIONS):
            for task_index, task_id in enumerate(TASKS):
                duration = (
                    18 + participant_index + task_index
                    if condition == "nutrisense"
                    else 32 + participant_index + task_index
                )
                success = not (
                    condition == "standardized_assistance"
                    and (participant_index + task_index) % 7 == 0
                )
                assistance = "none" if success else "prompt"
                started = base + timedelta(
                    days=participant_index,
                    minutes=condition_index * 60 + task_index * 5,
                )
                usability_rows.append({
                    "session_id": session_id,
                    "participant_id": participant_id,
                    "schema_version": "1.0",
                    "protocol_version": "synthetic-development-only",
                    "approval_reference": "NOT-AN-ETHICS-APPROVAL",
                    "data_origin": "synthetic",
                    "counterbalance_sequence": sequence,
                    "session_date": started.isoformat(),
                    "task_id": task_id,
                    "condition": condition,
                    "status": "completed" if success else "failed",
                    "started_at": started.isoformat(),
                    "ended_at": (started + timedelta(seconds=duration)).isoformat(),
                    "duration_seconds": float(duration),
                    "success": success,
                    "error_count": 0 if success else 1,
                    "assistance_level": assistance,
                    "abort_reason": None if success else "synthetic_task_failure",
                    "timing_source": "monotonic",
                    "manually_edited": False,
                    "edit_reason": None,
                    "researcher_note": "SYNTHETIC FIXTURE — NO HUMAN DATA",
                })
        submission_id = str(UUID(int=2000 + participant_index))
        answers = {
            "q1": "Birinden yardım istiyordum",
            "q2": 3 + participant_index % 3,
            "q3": 3 + (participant_index + 1) % 3,
            "q4": 2 + participant_index % 4,
            "q5": ("Evet", "Hayır", "Belki")[participant_index % 3],
            "q6": "Sentetik fixture yanıtı; insan katılımcı yoktur.",
            "q7": "Sentetik geliştirme önerisi.",
            "q8": 3 + participant_index % 3,
        }
        for question_id, answer in answers.items():
            survey_rows.append({
                "submission_id": submission_id,
                "participant_id": participant_id,
                "protocol_version": "synthetic-development-only",
                "approval_reference": "NOT-AN-ETHICS-APPROVAL",
                "survey_version": "1.0",
                "data_origin": "synthetic",
                "question_id": question_id,
                "answer": answer,
                "answered_at": base.isoformat(),
                "completion_seconds": 90,
                "submitted_at": base.isoformat(),
            })
    return (
        {"schema_version": "1.0", "synthetic": True, "rows": usability_rows},
        {"schema_version": "1.0", "synthetic": True, "rows": survey_rows},
    )


def write_fixture(output_dir: Path, participant_count: int = 8) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    usability, survey = build_fixture(participant_count)
    usability_path = output_dir / "usability_tidy.synthetic.json"
    survey_path = output_dir / "survey_tidy.synthetic.json"
    usability_path.write_text(
        json.dumps(usability, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    survey_path.write_text(
        json.dumps(survey, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return usability_path, survey_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--participants", type=int, default=8)
    args = parser.parse_args()
    if args.participants < 2:
        parser.error("Sentetik fixture en az iki sahte participant içermelidir.")
    usability, survey = write_fixture(args.output, args.participants)
    print("SYNTHETIC TEST DATA ONLY")
    print(usability)
    print(survey)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
