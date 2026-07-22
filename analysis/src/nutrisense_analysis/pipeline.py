from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats

from . import ANALYSIS_PLAN_VERSION, __version__


EXPECTED_TASKS = {f"t{index}" for index in range(1, 7)}
CONDITIONS = ("nutrisense", "standardized_assistance")
LIKERT_QUESTIONS = {"q2", "q3", "q4", "q8"}
OPEN_TEXT_QUESTIONS = {"q6", "q7"}
ASSISTANCE_LEVELS = {"none", "prompt", "partial", "full"}
TASK_MAX_SECONDS = {"t1": 180, "t2": 300, "t3": 180, "t4": 300, "t5": 180, "t6": 180}
ALPHA = 0.05
BOOTSTRAP_ITERATIONS = 10_000
PERMUTATION_ITERATIONS = 100_000
RANDOM_SEED = 2209
EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
PHONE_RE = re.compile(r"(?<!\d)(?:\+?\d[\s().-]*){7,15}(?!\d)")


class DataQualityError(ValueError):
    pass


@dataclass(frozen=True)
class LoadedExport:
    frame: pd.DataFrame
    checksum: str
    path: Path


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _manifest_path(path: Path) -> str:
    """Avoid leaking workstation/user directory names into analysis artefacts."""
    try:
        return path.resolve().relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.name


def _json_dump(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _load_export(path: Path) -> LoadedExport:
    payload = path.read_bytes()
    checksum = _sha256_bytes(payload)
    if path.suffix.lower() == ".csv":
        frame = pd.read_csv(path)
    else:
        decoded = json.loads(payload.decode("utf-8"))
        rows = decoded if isinstance(decoded, list) else decoded.get("rows")
        if not isinstance(rows, list):
            raise DataQualityError(f"{path.name}: 'rows' listesi bulunamadı.")
        frame = pd.DataFrame(rows)
    return LoadedExport(frame=frame, checksum=checksum, path=path)


def _require_columns(frame: pd.DataFrame, columns: Iterable[str], label: str) -> None:
    missing = sorted(set(columns) - set(frame.columns))
    if missing:
        raise DataQualityError(f"{label}: zorunlu kolonlar eksik: {', '.join(missing)}")


def _as_bool(series: pd.Series, label: str) -> pd.Series:
    accepted = {True: True, False: False, 1: True, 0: False, "true": True, "false": False}
    normalized = series.map(lambda value: accepted.get(value, accepted.get(str(value).lower())))
    if normalized.isna().any():
        raise DataQualityError(f"{label}: success alanında boolean olmayan değer var.")
    return normalized.astype(bool)


def _validate_origin(frame: pd.DataFrame, mode: str, label: str) -> None:
    expected = "participant" if mode == "real" else "synthetic"
    origins = set(frame["data_origin"].dropna().astype(str))
    if origins != {expected}:
        raise DataQualityError(
            f"{label}: --mode {mode} yalnız data_origin={expected} kabul eder; bulunan={sorted(origins)}"
        )
    if mode == "real":
        for column in ("protocol_version", "approval_reference"):
            values = frame[column].fillna("").astype(str).str.strip()
            unsafe = values.str.contains(
                r"^(?:$|TODO|TBD|PLACEHOLDER|REPLACE|EXAMPLE|NOT-AN-ETHICS-APPROVAL)",
                case=False,
                regex=True,
            )
            if unsafe.any():
                raise DataQualityError(f"{label}: gerçek veri için geçersiz {column} bulundu.")


def validate_usability(export: LoadedExport, mode: str) -> tuple[pd.DataFrame, list[str]]:
    frame = export.frame.copy()
    required = {
        "session_id",
        "participant_id",
        "schema_version",
        "protocol_version",
        "approval_reference",
        "data_origin",
        "counterbalance_sequence",
        "task_id",
        "condition",
        "status",
        "duration_seconds",
        "success",
        "error_count",
        "assistance_level",
        "abort_reason",
        "timing_source",
        "manually_edited",
    }
    _require_columns(frame, required, "usability export")
    if frame.empty:
        raise DataQualityError("usability export boş.")
    _validate_origin(frame, mode, "usability export")

    frame["participant_id"] = frame["participant_id"].astype(str)
    frame["session_id"] = frame["session_id"].astype(str)
    frame["task_id"] = frame["task_id"].astype(str)
    frame["condition"] = frame["condition"].astype(str)
    frame["duration_seconds"] = pd.to_numeric(frame["duration_seconds"], errors="coerce")
    frame["error_count"] = pd.to_numeric(frame["error_count"], errors="coerce")
    frame["success"] = _as_bool(frame["success"], "usability export")
    frame["manually_edited"] = _as_bool(
        frame["manually_edited"], "usability export manually_edited"
    )

    errors: list[str] = []
    duplicate = frame.duplicated(["participant_id", "task_id", "condition"], keep=False)
    if duplicate.any():
        errors.append(f"duplicate participant/task/condition satırı: {int(duplicate.sum())}")
    if frame["session_id"].isna().any() or (frame["session_id"].str.len() == 0).any():
        errors.append("boş session_id")
    session_participants = frame.groupby("session_id")["participant_id"].nunique()
    if (session_participants > 1).any():
        errors.append("aynı session_id birden fazla participant_id ile eşleşiyor")
    if frame["duration_seconds"].isna().any():
        errors.append("eksik veya sayısal olmayan duration_seconds")
    if (frame["duration_seconds"] < 0).any():
        errors.append("negatif duration_seconds")
    if frame["error_count"].isna().any() or (frame["error_count"] < 0).any():
        errors.append("negatif veya geçersiz error_count")
    if not set(frame["task_id"]).issubset(EXPECTED_TASKS):
        errors.append("tanımsız task_id")
    if not set(frame["condition"]).issubset(set(CONDITIONS)):
        errors.append("tanımsız condition")
    if not set(frame["assistance_level"].astype(str)).issubset(ASSISTANCE_LEVELS):
        errors.append("tanımsız assistance_level")
    sequence_values = set(frame["counterbalance_sequence"].dropna().astype(str))
    if (
        frame["counterbalance_sequence"].isna().any()
        or not sequence_values.issubset({"AB", "BA"})
        or not sequence_values
    ):
        errors.append("counterbalance_sequence AB/BA değil veya eksik")
    impossible_success = frame["success"] & (
        frame["abort_reason"].fillna("").astype(str).str.len().gt(0)
        | frame["status"].astype(str).isin({"failed", "aborted", "not_started"})
    )
    if impossible_success.any():
        errors.append(f"abort/failed ile birlikte success=true: {int(impossible_success.sum())}")
    over_limit = frame.apply(
        lambda row: bool(row["success"])
        and float(row["duration_seconds"]) > TASK_MAX_SECONDS.get(str(row["task_id"]), math.inf) + 5,
        axis=1,
    )
    if over_limit.any():
        errors.append(f"başarılı görev maksimum süreyi aşıyor: {int(over_limit.sum())}")

    expected_pairs = {(task, condition) for task in EXPECTED_TASKS for condition in CONDITIONS}
    for participant_id, group in frame.groupby("participant_id"):
        found = set(zip(group["task_id"], group["condition"]))
        if found != expected_pairs:
            missing = len(expected_pairs - found)
            extra = len(found - expected_pairs)
            errors.append(
                f"katılımcı {blind_identifier(participant_id)}: eksik görev-koşul={missing}, fazla={extra}"
            )
    if errors:
        raise DataQualityError("; ".join(errors))

    warnings: list[str] = []
    manual = frame["manually_edited"]
    missing_reason = manual & frame.get("edit_reason", pd.Series(index=frame.index, dtype=object)).fillna("").astype(str).str.len().eq(0)
    if missing_reason.any():
        raise DataQualityError("manuel düzenleme var fakat edit_reason eksik.")
    if manual.any():
        warnings.append(f"manuel düzenlenmiş görev satırı: {int(manual.sum())}")
    return frame, warnings


def validate_survey(export: LoadedExport, mode: str) -> tuple[pd.DataFrame, list[str]]:
    frame = export.frame.copy()
    required = {
        "submission_id",
        "participant_id",
        "protocol_version",
        "approval_reference",
        "survey_version",
        "data_origin",
        "question_id",
        "answer",
        "submitted_at",
    }
    _require_columns(frame, required, "survey export")
    if frame.empty:
        raise DataQualityError("survey export boş.")
    _validate_origin(frame, mode, "survey export")
    frame["participant_id"] = frame["participant_id"].astype(str)
    frame["question_id"] = frame["question_id"].astype(str)
    duplicate = frame.duplicated(["submission_id", "question_id"], keep=False)
    if duplicate.any():
        raise DataQualityError(
            f"survey export duplicate submission/question satırı: {int(duplicate.sum())}"
        )
    participant_submissions = (
        frame[["participant_id", "survey_version", "submission_id"]]
        .drop_duplicates()
        .groupby(["participant_id", "survey_version"])["submission_id"]
        .nunique()
    )
    if (participant_submissions > 1).any():
        raise DataQualityError("aynı participant/survey_version için birden fazla submission var.")
    warnings: list[str] = []
    for question_id in LIKERT_QUESTIONS:
        values = pd.to_numeric(
            frame.loc[frame["question_id"] == question_id, "answer"], errors="coerce"
        )
        if values.isna().any() or ((values < 1) | (values > 5)).any():
            raise DataQualityError(f"{question_id}: Likert yanıtı 1..5 dışında.")
    pii_flags = 0
    for value in frame.loc[frame["question_id"].isin(OPEN_TEXT_QUESTIONS), "answer"]:
        text = str(value or "")
        if EMAIL_RE.search(text) or PHONE_RE.search(text):
            pii_flags += 1
    if pii_flags:
        warnings.append(
            f"açık uçlu yanıtta olası kişisel veri; yalnız redakte çıktı üretildi: {pii_flags}"
        )
    return frame, warnings


def blind_identifier(value: str) -> str:
    digest = hashlib.sha256(f"nutrisense-analysis-v1:{value}".encode()).hexdigest()
    return f"P-{digest[:12]}"


def _blind_frames(usability: pd.DataFrame, survey: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    usability = usability.copy()
    survey = survey.copy()
    usability["participant_analysis_id"] = usability["participant_id"].map(blind_identifier)
    survey["participant_analysis_id"] = survey["participant_id"].map(blind_identifier)
    usability = usability.drop(columns=["participant_id"])
    survey = survey.drop(columns=["participant_id"])
    return usability, survey


def wilson_interval(successes: int, total: int, alpha: float = ALPHA) -> tuple[float, float]:
    if total == 0:
        return math.nan, math.nan
    z = stats.norm.ppf(1 - alpha / 2)
    proportion = successes / total
    denominator = 1 + z * z / total
    centre = (proportion + z * z / (2 * total)) / denominator
    margin = z * math.sqrt(
        proportion * (1 - proportion) / total + z * z / (4 * total * total)
    ) / denominator
    return centre - margin, centre + margin


def bootstrap_ci(values: np.ndarray, statistic=np.mean) -> tuple[float, float]:
    values = np.asarray(values, dtype=float)
    if len(values) < 2:
        return math.nan, math.nan
    rng = np.random.default_rng(RANDOM_SEED)
    indices = rng.integers(0, len(values), size=(BOOTSTRAP_ITERATIONS, len(values)))
    estimates = np.apply_along_axis(statistic, 1, values[indices])
    return tuple(np.quantile(estimates, [0.025, 0.975]).tolist())


def paired_permutation_pvalue(differences: np.ndarray) -> float:
    differences = np.asarray(differences, dtype=float)
    differences = differences[np.isfinite(differences)]
    if len(differences) == 0:
        return math.nan
    observed = abs(float(np.mean(differences)))
    if len(differences) <= 18:
        signs = np.array(
            [
                [1 if (mask >> bit) & 1 else -1 for bit in range(len(differences))]
                for mask in range(2 ** len(differences))
            ],
            dtype=float,
        )
    else:
        rng = np.random.default_rng(RANDOM_SEED)
        signs = rng.choice(
            (-1.0, 1.0), size=(PERMUTATION_ITERATIONS, len(differences))
        )
    permuted = np.abs(np.mean(signs * differences, axis=1))
    return float((np.sum(permuted >= observed) + 1) / (len(permuted) + 1))


def rank_biserial(differences: np.ndarray) -> float:
    differences = np.asarray(differences, dtype=float)
    differences = differences[np.isfinite(differences) & (differences != 0)]
    if len(differences) == 0:
        return 0.0
    ranks = stats.rankdata(np.abs(differences))
    positive = float(ranks[differences > 0].sum())
    negative = float(ranks[differences < 0].sum())
    return (positive - negative) / (positive + negative)


def _holm_adjust(pvalues: dict[str, float]) -> dict[str, float]:
    finite = sorted(
        ((key, value) for key, value in pvalues.items() if math.isfinite(value)),
        key=lambda item: item[1],
    )
    adjusted: dict[str, float] = {key: math.nan for key in pvalues}
    running = 0.0
    count = len(finite)
    for index, (key, value) in enumerate(finite):
        running = max(running, min(1.0, (count - index) * value))
        adjusted[key] = running
    return adjusted


def _metadata_columns(frame: pd.DataFrame, metadata: dict[str, str]) -> pd.DataFrame:
    output = frame.copy()
    for key, value in reversed(list(metadata.items())):
        output.insert(0, key, value)
    return output


def _record(
    manifest: dict[str, Any],
    result_id: str,
    values: dict[str, Any],
    source_variables: list[str],
    method: str,
    artifact: str,
) -> None:
    manifest["results"][result_id] = {
        "values": _json_safe(values),
        "source_variables": source_variables,
        "method": method,
        "artifact": artifact,
        "command": manifest["command"],
    }


def _json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating, float)):
        return None if not math.isfinite(float(value)) else float(value)
    if isinstance(value, (np.bool_,)):
        return bool(value)
    return value


def _analyse_usability(
    frame: pd.DataFrame,
    output_dir: Path,
    metadata: dict[str, str],
    manifest: dict[str, Any],
) -> None:
    frame = frame.copy()
    frame["independent_success"] = frame["success"] & frame["assistance_level"].eq("none")

    condition_rows = []
    for condition, group in frame.groupby("condition", sort=True):
        successes = int(group["independent_success"].sum())
        total = len(group)
        low, high = wilson_interval(successes, total)
        successful_durations = group.loc[group["independent_success"], "duration_seconds"]
        row = {
            "result_id": f"condition.{condition}",
            "condition": condition,
            "participants": int(group["participant_analysis_id"].nunique()),
            "attempts": total,
            "independent_successes": successes,
            "independent_success_rate": successes / total,
            "success_ci95_low": low,
            "success_ci95_high": high,
            "successful_duration_median_seconds": float(successful_durations.median()),
            "successful_duration_iqr_seconds": float(
                successful_durations.quantile(0.75) - successful_durations.quantile(0.25)
            ),
        }
        condition_rows.append(row)
        _record(
            manifest,
            row["result_id"],
            row,
            ["condition", "success", "assistance_level", "duration_seconds"],
            "Independent success = success AND no assistance; Wilson 95% CI; median/IQR duration.",
            "tables/condition_descriptives.csv",
        )
    condition_table = pd.DataFrame(condition_rows)
    _metadata_columns(condition_table, metadata).to_csv(
        output_dir / "tables" / "condition_descriptives.csv", index=False
    )

    participant = (
        frame.groupby(["participant_analysis_id", "condition"], as_index=False)
        .agg(
            independent_success_rate=("independent_success", "mean"),
            independent_success_count=("independent_success", "sum"),
            task_count=("task_id", "count"),
        )
    )
    duration_participant = (
        frame.loc[frame["independent_success"]]
        .groupby(["participant_analysis_id", "condition"], as_index=False)
        .agg(median_duration_seconds=("duration_seconds", "median"))
    )
    success_wide = participant.pivot(
        index="participant_analysis_id", columns="condition", values="independent_success_rate"
    ).dropna()
    duration_wide = duration_participant.pivot(
        index="participant_analysis_id", columns="condition", values="median_duration_seconds"
    ).dropna()

    success_diff = (
        success_wide["nutrisense"] - success_wide["standardized_assistance"]
    ).to_numpy()
    duration_diff = (
        duration_wide["nutrisense"] - duration_wide["standardized_assistance"]
    ).to_numpy()
    success_ci = bootstrap_ci(success_diff)
    duration_ci = bootstrap_ci(duration_diff, statistic=np.median)
    raw_p = {
        "primary.success": paired_permutation_pvalue(success_diff),
        "primary.duration": paired_permutation_pvalue(duration_diff),
    }
    adjusted = _holm_adjust(raw_p)
    wilcoxon_p = math.nan
    if np.count_nonzero(duration_diff) >= 5:
        wilcoxon_p = float(stats.wilcoxon(duration_diff, zero_method="wilcox").pvalue)

    inference_rows = [
        {
            "result_id": "primary.success",
            "outcome": "participant independent success rate",
            "paired_participants": len(success_diff),
            "effect": float(np.mean(success_diff)),
            "effect_unit": "proportion_point_difference_nutrisense_minus_control",
            "effect_ci95_low": success_ci[0],
            "effect_ci95_high": success_ci[1],
            "p_raw": raw_p["primary.success"],
            "p_holm": adjusted["primary.success"],
            "effect_size": float(np.mean(success_diff)),
            "effect_size_name": "paired_mean_proportion_difference",
        },
        {
            "result_id": "primary.duration",
            "outcome": "participant median duration among independent successes",
            "paired_participants": len(duration_diff),
            "effect": float(np.median(duration_diff)),
            "effect_unit": "seconds_median_difference_nutrisense_minus_control",
            "effect_ci95_low": duration_ci[0],
            "effect_ci95_high": duration_ci[1],
            "p_raw": raw_p["primary.duration"],
            "p_holm": adjusted["primary.duration"],
            "effect_size": rank_biserial(duration_diff),
            "effect_size_name": "paired_rank_biserial_correlation",
            "wilcoxon_sensitivity_p": wilcoxon_p,
        },
    ]
    inference_table = pd.DataFrame(inference_rows)
    for row in inference_rows:
        _record(
            manifest,
            row["result_id"],
            row,
            ["participant_analysis_id", "condition", "success", "assistance_level", "duration_seconds"],
            "Participant-level paired sign-flip permutation; 10,000 participant bootstrap CI; Holm for two co-primary outcomes.",
            "tables/primary_inference.csv",
        )
    _metadata_columns(inference_table, metadata).to_csv(
        output_dir / "tables" / "primary_inference.csv", index=False
    )

    task_rows = []
    task_pvalues: dict[str, float] = {}
    for task_id, task_group in frame.groupby("task_id", sort=True):
        pair = task_group.pivot(
            index="participant_analysis_id", columns="condition", values="duration_seconds"
        ).dropna()
        differences = (pair["nutrisense"] - pair["standardized_assistance"]).to_numpy()
        result_id = f"secondary.duration.{task_id}"
        task_pvalues[result_id] = paired_permutation_pvalue(differences)
        for condition, group in task_group.groupby("condition", sort=True):
            successes = int(group["independent_success"].sum())
            low, high = wilson_interval(successes, len(group))
            task_rows.append({
                "result_id": f"task.{task_id}.{condition}",
                "task_id": task_id,
                "condition": condition,
                "attempts": len(group),
                "independent_success_rate": successes / len(group),
                "success_ci95_low": low,
                "success_ci95_high": high,
                "duration_median_seconds": float(group["duration_seconds"].median()),
                "duration_iqr_seconds": float(
                    group["duration_seconds"].quantile(0.75)
                    - group["duration_seconds"].quantile(0.25)
                ),
                "paired_duration_p_raw": task_pvalues[result_id],
            })
    task_adjusted = _holm_adjust(task_pvalues)
    for row in task_rows:
        key = f"secondary.duration.{row['task_id']}"
        row["paired_duration_p_holm_6_tasks"] = task_adjusted[key]
        _record(
            manifest,
            row["result_id"],
            row,
            ["task_id", "condition", "duration_seconds", "success", "assistance_level"],
            "Task descriptive statistics; paired sign-flip duration test with Holm correction over six tasks.",
            "tables/task_descriptives.csv",
        )
    _metadata_columns(pd.DataFrame(task_rows), metadata).to_csv(
        output_dir / "tables" / "task_descriptives.csv", index=False
    )

    sensitivity = []
    for definition, subset in {
        "all_recorded_attempts": frame,
        "completed_with_any_assistance": frame.loc[frame["success"]],
        "independent_success_only": frame.loc[frame["independent_success"]],
        "exclude_manual_timing": frame.loc[~frame["manually_edited"].astype(bool)],
    }.items():
        summary = subset.groupby("condition")["duration_seconds"].median().to_dict()
        sensitivity.append({
            "result_id": f"sensitivity.{definition}",
            "definition": definition,
            "nutrisense_median_seconds": summary.get("nutrisense"),
            "control_median_seconds": summary.get("standardized_assistance"),
            "rows": len(subset),
        })
    sensitivity_table = pd.DataFrame(sensitivity)
    for row in sensitivity:
        _record(
            manifest,
            row["result_id"],
            row,
            ["condition", "duration_seconds", "success", "assistance_level", "manually_edited"],
            "Pre-specified duration-set sensitivity summary; no outlier deletion.",
            "tables/sensitivity_analysis.csv",
        )
    _metadata_columns(sensitivity_table, metadata).to_csv(
        output_dir / "tables" / "sensitivity_analysis.csv", index=False
    )

    figure_metadata = {
        "Title": "NutriSense condition success rates",
        "Author": "NutriSense reproducible analysis pipeline",
        "Description": json.dumps(metadata, sort_keys=True),
    }
    plot = condition_table.set_index("condition")["independent_success_rate"]
    ax = plot.plot(kind="bar", color=["#2E7D32", "#607D8B"], ylim=(0, 1))
    ax.set_ylabel("Independent success proportion")
    ax.set_xlabel("Condition")
    ax.set_title("Independent task success by condition")
    plt.tight_layout()
    plt.savefig(output_dir / "figures" / "success_rate.png", dpi=160, metadata=figure_metadata)
    plt.close()

    ax = frame.boxplot(column="duration_seconds", by="condition", grid=False)
    ax.set_ylabel("Duration (seconds)")
    ax.set_xlabel("Condition")
    ax.set_title("Recorded task duration by condition")
    plt.suptitle("")
    plt.tight_layout()
    plt.savefig(output_dir / "figures" / "duration_boxplot.png", dpi=160, metadata=figure_metadata)
    plt.close()
    manifest["artifacts"]["figures/success_rate.png"] = {
        "source_result_ids": [row["result_id"] for row in condition_rows],
        "metadata": metadata,
    }
    manifest["artifacts"]["figures/duration_boxplot.png"] = {
        "source_result_ids": ["primary.duration"],
        "metadata": metadata,
    }


def _redact_open_text(value: Any) -> str:
    text = str(value or "")
    text = EMAIL_RE.sub("[EMAIL_REDACTED]", text)
    return PHONE_RE.sub("[PHONE_REDACTED]", text)


def _analyse_survey(
    frame: pd.DataFrame,
    output_dir: Path,
    metadata: dict[str, str],
    manifest: dict[str, Any],
) -> None:
    rows = []
    for question_id in sorted(LIKERT_QUESTIONS):
        values = pd.to_numeric(
            frame.loc[frame["question_id"] == question_id, "answer"], errors="coerce"
        ).dropna()
        counts = {str(score): int((values == score).sum()) for score in range(1, 6)}
        row = {
            "result_id": f"survey.{question_id}",
            "question_id": question_id,
            "n": len(values),
            "median": float(values.median()),
            "q1": float(values.quantile(0.25)),
            "q3": float(values.quantile(0.75)),
            "iqr": float(values.quantile(0.75) - values.quantile(0.25)),
            **{f"count_{score}": counts[str(score)] for score in range(1, 6)},
        }
        rows.append(row)
        _record(
            manifest,
            row["result_id"],
            row,
            ["question_id", "answer"],
            "Item-level Likert count distribution and median/IQR; no total score or Cronbach alpha.",
            "tables/survey_likert.csv",
        )
    _metadata_columns(pd.DataFrame(rows), metadata).to_csv(
        output_dir / "tables" / "survey_likert.csv", index=False
    )

    qualitative = frame.loc[frame["question_id"].isin(OPEN_TEXT_QUESTIONS)].copy()
    qualitative["response_id"] = qualitative.apply(
        lambda row: _sha256_bytes(
            f"{row['submission_id']}:{row['question_id']}".encode()
        )[:16],
        axis=1,
    )
    qualitative["redacted_text"] = qualitative["answer"].map(_redact_open_text)
    safe_columns = [
        "response_id",
        "participant_analysis_id",
        "question_id",
        "redacted_text",
    ]
    _metadata_columns(qualitative[safe_columns], metadata).to_csv(
        output_dir / "tables" / "qualitative_redacted.csv", index=False
    )
    manifest["artifacts"]["tables/qualitative_redacted.csv"] = {
        "source_variables": ["submission_id", "question_id", "answer"],
        "method": "Regex redaction for email/phone; mandatory manual disclosure review before coding.",
        "metadata": metadata,
    }


def run_pipeline(
    usability_path: Path,
    survey_path: Path,
    output_root: Path,
    mode: str,
    command: str,
) -> Path:
    usability_export = _load_export(usability_path)
    survey_export = _load_export(survey_path)
    usability, usability_warnings = validate_usability(usability_export, mode)
    survey, survey_warnings = validate_survey(survey_export, mode)
    usability, survey = _blind_frames(usability, survey)

    combined_checksum = _sha256_bytes(
        f"{usability_export.checksum}:{survey_export.checksum}".encode()
    )
    generated_at = _utc_now()
    run_id = f"{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{combined_checksum[:12]}"
    output_dir = output_root / mode / run_id
    (output_dir / "tables").mkdir(parents=True, exist_ok=False)
    (output_dir / "figures").mkdir(parents=True, exist_ok=False)
    status = "REAL_DATA_ANALYZED" if mode == "real" else "SYNTHETIC_PIPELINE_TEST_ONLY"
    metadata = {
        "analysis_run_id": run_id,
        "data_checksum_sha256": combined_checksum,
        "generated_at_utc": generated_at,
        "analysis_plan_version": ANALYSIS_PLAN_VERSION,
        "synthetic": str(mode == "synthetic").lower(),
    }
    manifest: dict[str, Any] = {
        "status": status,
        "synthetic": mode == "synthetic",
        "analysis_run_id": run_id,
        "analysis_plan_version": ANALYSIS_PLAN_VERSION,
        "pipeline_version": __version__,
        "generated_at_utc": generated_at,
        "command": command,
        "inputs": {
            "usability": {
                "path": _manifest_path(usability_path),
                "checksum_sha256": usability_export.checksum,
                "rows": len(usability_export.frame),
            },
            "survey": {
                "path": _manifest_path(survey_path),
                "checksum_sha256": survey_export.checksum,
                "rows": len(survey_export.frame),
            },
            "combined_checksum_sha256": combined_checksum,
        },
        "quality_warnings": usability_warnings + survey_warnings,
        "results": {},
        "artifacts": {},
        "prohibited_claim_sources": [
            "docs/tubitak_sonuc_raporu.md",
            "docs/akademik_makale_taslak.md",
        ],
    }
    _analyse_usability(usability, output_dir, metadata, manifest)
    _analyse_survey(survey, output_dir, metadata, manifest)
    _json_dump(output_dir / "results_manifest.json", manifest)
    if mode == "real":
        _json_dump(output_root.parent / "results_manifest.json", manifest)
    _json_dump(
        output_dir / "artifact_metadata.json",
        {"metadata": metadata, "artifacts": sorted(manifest["artifacts"])},
    )
    _json_dump(
        output_root / mode / "LATEST_STATUS.json",
        {
            "status": status,
            "synthetic": mode == "synthetic",
            "analysis_run_id": run_id,
            "results_manifest": str(output_dir / "results_manifest.json"),
        },
    )
    return output_dir


def write_no_real_data_status(output_root: Path, command: str, missing: list[Path]) -> Path:
    generated_at = _utc_now()
    run_id = f"NO-REAL-DATA-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
    output_dir = output_root / "real" / run_id
    output_dir.mkdir(parents=True, exist_ok=False)
    payload = {
        "status": "NO REAL DATA",
        "synthetic": False,
        "analysis_run_id": run_id,
        "analysis_plan_version": ANALYSIS_PLAN_VERSION,
        "pipeline_version": __version__,
        "generated_at_utc": generated_at,
        "command": command,
        "missing_inputs": [_manifest_path(path) for path in missing],
        "results": {},
        "tables_generated": False,
        "figures_generated": False,
        "message": "Analiz hattı hazır, bilimsel sonuç yok.",
    }
    _json_dump(output_dir / "results_manifest.json", payload)
    _json_dump(output_root.parent / "results_manifest.json", payload)
    _json_dump(output_dir / "STATUS.json", payload)
    _json_dump(output_root / "real" / "LATEST_STATUS.json", payload)
    return output_dir


def _parser() -> argparse.ArgumentParser:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="NutriSense reproducible HCI analysis; draft reports are never inputs."
    )
    parser.add_argument("--mode", choices=("real", "synthetic"), default="real")
    parser.add_argument(
        "--usability",
        type=Path,
        default=root / "data" / "real" / "usability_tidy.json",
    )
    parser.add_argument(
        "--survey",
        type=Path,
        default=root / "data" / "real" / "survey_tidy.json",
    )
    parser.add_argument(
        "--output-root", type=Path, default=root / "outputs"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    command = " ".join([Path(sys.executable).name, "analysis/run_analysis.py", *(argv or sys.argv[1:])])
    missing = [path for path in (args.usability, args.survey) if not path.exists()]
    if missing:
        if args.mode == "synthetic":
            parser.error("Sentetik mod için fixture yolları açıkça mevcut olmalıdır.")
        output_dir = write_no_real_data_status(args.output_root, command, missing)
        print("STATUS: NO REAL DATA")
        print("Analiz hattı hazır, bilimsel sonuç yok.")
        print(f"Manifest: {output_dir / 'results_manifest.json'}")
        return 0
    try:
        output_dir = run_pipeline(
            args.usability,
            args.survey,
            args.output_root,
            args.mode,
            command,
        )
    except (DataQualityError, json.JSONDecodeError, pd.errors.ParserError) as exc:
        print(f"DATA QUALITY FAILURE: {exc}", file=sys.stderr)
        return 2
    print("STATUS: REAL DATA ANALYZED" if args.mode == "real" else "STATUS: SYNTHETIC PIPELINE TEST ONLY")
    print(f"Manifest: {output_dir / 'results_manifest.json'}")
    return 0
