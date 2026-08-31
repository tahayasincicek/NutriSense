"""Fail closed when deployment safety invariants drift."""

from __future__ import annotations

import re
from pathlib import Path

import yaml


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"DEPLOYMENT_CHECK=FAIL reason={message}")


def check_lock(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    requirement_lines = [
        line
        for line in text.splitlines()
        if line and not line.startswith((" ", "#", "--"))
    ]
    require(requirement_lines, f"{path.name} boş")
    require(
        all("==" in line for line in requirement_lines),
        f"{path.name} tam sürüm sabitlemiyor",
    )
    require("--hash=sha256:" in text, f"{path.name} hash içermiyor")


def main() -> None:
    dockerfile = (BACKEND_ROOT / "Dockerfile").read_text(encoding="utf-8")
    compose_text = (BACKEND_ROOT / "compose.staging.yml").read_text(
        encoding="utf-8"
    )
    compose = yaml.safe_load(compose_text)
    workflow = (
        PROJECT_ROOT / ".github" / "workflows" / "ci.yml"
    ).read_text(encoding="utf-8")
    production_spec = (
        PROJECT_ROOT / "deploy" / "production" / "deployment-spec.yaml"
    ).read_text(encoding="utf-8")

    require(
        re.search(r"^ARG PYTHON_IMAGE=.+@sha256:[0-9a-f]{64}$", dockerfile, re.M)
        is not None,
        "Python base image digest ile sabit değil",
    )
    require("AS production" in dockerfile, "production build target yok")
    require("USER 10001:10001" in dockerfile, "container non-root değil")
    require("--require-hashes" in dockerfile, "hash kilidi build'de zorlanmıyor")

    backend = compose["services"]["backend"]
    require(backend.get("read_only") is True, "backend root filesystem yazılabilir")
    require(
        backend.get("cap_drop") == ["ALL"],
        "backend Linux capabilities kapatılmamış",
    )
    require(
        backend["environment"]["RESEARCH_MODE"] == "synthetic",
        "staging gerçek araştırma modunda",
    )
    require(
        backend["environment"]["NOTIFICATION_MODE"] == "sandbox",
        "staging gerçek bildirim modunda",
    )
    require(
        "continue-on-error" not in workflow and "|| true" not in workflow,
        "CI hata maskeleyen ifade içeriyor",
    )
    require(
        "TEMPLATE_NOT_DEPLOYED" in production_spec,
        "production şablonu dağıtılmış gibi görünüyor",
    )
    require(
        "image_digest:" in production_spec,
        "production şablonunda immutable image kapısı yok",
    )

    check_lock(BACKEND_ROOT / "requirements.lock")
    check_lock(BACKEND_ROOT / "requirements-dev.lock")
    print("DEPLOYMENT_CHECK=PASS")


if __name__ == "__main__":
    main()
