#!/usr/bin/env python3
"""Controlled, local-only dynamic security smoke test.

The script deliberately uses an isolated in-memory database and refuses to run
outside the test environment. It never calls external providers.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


os.environ.setdefault("APP_ENVIRONMENT", "test")
os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")
os.environ.setdefault(
    "JWT_SECRET_KEY",
    "synthetic-local-security-smoke-key-not-for-production",
)
os.environ.setdefault("DEBUG", "false")
os.environ.setdefault("MIGRATION_CHECK_ENABLED", "false")

if os.environ["APP_ENVIRONMENT"].lower() != "test":
    raise SystemExit("SECURITY_SMOKE=REFUSED reason=non_test_environment")
if not os.environ["DATABASE_URL"].startswith("sqlite"):
    raise SystemExit("SECURITY_SMOKE=REFUSED reason=non_isolated_database")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"SECURITY_SMOKE=FAIL check={message}")


with TestClient(app) as client:
    live = client.get("/health/live")
    require(live.status_code == 200, "liveness")
    require(live.headers.get("x-content-type-options") == "nosniff", "nosniff")
    require(live.headers.get("x-frame-options") == "DENY", "frame_deny")
    require(live.headers.get("cache-control") == "no-store", "no_store")

    unauthorized = client.get("/api/v1/users/me")
    require(unauthorized.status_code in {401, 403}, "protected_route")

    untrusted_host = client.get(
        "/health/live",
        headers={"Host": "attacker.invalid"},
    )
    require(untrusted_host.status_code == 400, "trusted_host")

    unsafe_request_id = client.get(
        "/health/live",
        headers={"X-Request-ID": "line-break%0d%0aInjected:true"},
    )
    returned_id = unsafe_request_id.headers.get("x-request-id", "")
    require("%0d" not in returned_id.lower(), "request_id_sanitized")
    require("\r" not in returned_id and "\n" not in returned_id, "header_injection")

print("SECURITY_SMOKE=PASS scope=LOCAL_TESTCLIENT_NO_EXTERNAL_CALLS")
