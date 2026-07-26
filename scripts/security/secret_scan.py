#!/usr/bin/env python3
"""Redacted secret scan for the tracked tree and optional Git history.

Only rule identifiers, paths and abbreviated commit identifiers are printed.
Matched values and source lines are deliberately never emitted.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAX_TEXT_BYTES = 2 * 1024 * 1024


@dataclass(frozen=True)
class Rule:
    rule_id: str
    pattern: re.Pattern[str]
    value_group: int | None = None


RULES = (
    Rule(
        "PRIVATE_KEY",
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
    ),
    Rule("AWS_ACCESS_KEY", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    Rule("GOOGLE_API_KEY", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    Rule(
        "GITHUB_TOKEN",
        re.compile(r"\b(?:github_pat_[A-Za-z0-9_]{40,}|gh[pousr]_[A-Za-z0-9]{30,})\b"),
    ),
    Rule(
        "SLACK_TOKEN",
        re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    ),
    Rule(
        "STRIPE_SECRET",
        re.compile(r"\bsk_(?:live|test)_[A-Za-z0-9]{20,}\b"),
    ),
    Rule(
        "GENERIC_QUOTED_SECRET",
        re.compile(
            r"(?im)\b(?:api[_-]?key|auth[_-]?token|access[_-]?token|"
            r"client[_-]?secret|jwt[_-]?secret(?:[_-]?key)?|password|passwd|"
            r"secret[_-]?key)\b\s*[=:]\s*[\"']"
            r"([A-Za-z0-9+/_.=-]{20,})[\"']"
        ),
        value_group=1,
    ),
    Rule(
        "ENV_SECRET_ASSIGNMENT",
        re.compile(
            r"(?im)^\s*(?:API_KEY|AUTH_TOKEN|ACCESS_TOKEN|CLIENT_SECRET|"
            r"JWT_SECRET_KEY|PASSWORD|DB_PASSWORD|SMTP_PASSWORD|"
            r"TWILIO_AUTH_TOKEN|NUTRITIONIX_API_KEY)\s*=\s*"
            r"([A-Za-z0-9+/_.=-]{20,})\s*$"
        ),
        value_group=1,
    ),
)

PLACEHOLDER_MARKERS = (
    "abcdefghijklmnopqrstuvwxyz",
    "change-me",
    "dummy",
    "example",
    "fake",
    "not-a-real",
    "placeholder",
    "replace",
    "sample",
    "synthetic",
    "test-secret",
    "your-",
    "your_",
    "xxx",
)

CANDIDATE_PATTERN = (
    r"BEGIN .*PRIVATE KEY|AKIA[A-Z0-9]{16}|ASIA[A-Z0-9]{16}|AIza|"
    r"github_pat_|gh[pousr]_|xox[baprs]-|sk_(live|test)_|"
    r"(api[_-]?key|auth[_-]?token|access[_-]?token|client[_-]?secret|"
    r"jwt[_-]?secret|password|passwd|secret[_-]?key)[[:space:]]*[=:]"
)


def _git(*args: str, text: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=text,
        encoding="utf-8" if text else None,
        errors="replace" if text else None,
    )


def _is_placeholder(value: str) -> bool:
    normalized = value.strip().strip("\"'").lower()
    return any(marker in normalized for marker in PLACEHOLDER_MARKERS)


def scan_text(path: str, content: str) -> set[str]:
    findings: set[str] = set()
    example_file = path.endswith(".example") or ".example." in path
    for rule in RULES:
        for match in rule.pattern.finditer(content):
            if rule.value_group is not None:
                value = match.group(rule.value_group)
                if example_file or _is_placeholder(value):
                    continue
            findings.add(rule.rule_id)
    return findings


def _tracked_paths(commit: str | None) -> list[str]:
    if commit:
        result = _git("grep", "-I", "-l", "-E", CANDIDATE_PATTERN, commit, "--")
        prefix = f"{commit}:"
        return sorted(
            line[len(prefix):] if line.startswith(prefix) else line
            for line in result.stdout.splitlines()
            if line.strip()
        )
    result = _git("grep", "-I", "-l", "-E", CANDIDATE_PATTERN, "--")
    return sorted(line for line in result.stdout.splitlines() if line.strip())


def _read_blob(path: str, commit: str | None) -> str | None:
    if commit:
        result = _git("show", f"{commit}:{path}", text=False)
        raw = result.stdout
    else:
        candidate = ROOT / path
        try:
            raw = candidate.read_bytes()
        except OSError:
            return None
    if len(raw) > MAX_TEXT_BYTES or b"\x00" in raw:
        return None
    return raw.decode("utf-8", errors="replace")


def scan_revision(commit: str | None) -> list[tuple[str, str, str]]:
    findings: list[tuple[str, str, str]] = []
    revision = commit[:12] if commit else "WORKTREE"
    for path in _tracked_paths(commit):
        content = _read_blob(path, commit)
        if content is None:
            continue
        for rule_id in sorted(scan_text(path, content)):
            findings.append((revision, path, rule_id))
    return findings


def _commits() -> list[str]:
    result = _git("rev-list", "--all")
    if result.returncode != 0:
        raise RuntimeError("Git history could not be enumerated.")
    return [line for line in result.stdout.splitlines() if line]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--history",
        action="store_true",
        help="Scan every reachable commit in addition to the tracked worktree.",
    )
    args = parser.parse_args()

    all_findings = scan_revision(None)
    if args.history:
        seen: set[tuple[str, str]] = set()
        for commit in _commits():
            for revision, path, rule_id in scan_revision(commit):
                key = (path, rule_id)
                if key not in seen:
                    all_findings.append((revision, path, rule_id))
                    seen.add(key)

    if all_findings:
        print("SECRET_SCAN=FAIL")
        for revision, path, rule_id in sorted(set(all_findings)):
            print(f"finding rule={rule_id} revision={revision} path={path}")
        print("Matched values and lines are intentionally redacted.")
        return 1

    scope = "TRACKED_TREE_AND_HISTORY" if args.history else "TRACKED_TREE"
    print(f"SECRET_SCAN=PASS scope={scope}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
