"""PII-free post-deploy smoke checks for a staging-compatible environment."""

from __future__ import annotations

import argparse
import json
import os
import urllib.request


def get_json(url: str, *, operations: bool = False) -> tuple[dict, dict]:
    headers = {"X-Request-ID": "staging-smoke-0001"}
    if operations:
        token = os.environ.get("NUTRISENSE_OPERATIONS_TOKEN", "")
        if not token:
            raise SystemExit("STAGING_SMOKE=FAIL operations token missing")
        headers["X-Operations-Token"] = token
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=10) as response:
        response_headers = {
            key.lower(): value for key, value in response.headers.items()
        }
        return json.load(response), response_headers


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    live, live_headers = get_json(f"{base}/health/live")
    ready, _ = get_json(f"{base}/health/ready")
    capabilities, _ = get_json(f"{base}/health/capabilities")
    metrics, _ = get_json(f"{base}/operations/metrics", operations=True)

    assert live["status"] == "alive"
    assert live_headers.get("x-request-id") == "staging-smoke-0001"
    assert ready["status"] == "ready"
    assert ready["database"] is True and ready["migration"] is True
    assert capabilities["research"]["mode"] == "synthetic"
    assert capabilities["vision"]["enabled"] is False
    assert capabilities["nutrition"]["enabled"] is False
    assert metrics["queue_depth"] == 0
    assert "db_pool" in metrics and "revision" in metrics
    print("STAGING_SMOKE=PASS health=ready providers=disabled research=synthetic")


if __name__ == "__main__":
    main()
