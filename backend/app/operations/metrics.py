"""In-process low-cardinality metrics with no request or health data values."""

from __future__ import annotations

import threading
import time
from collections import Counter


class RuntimeMetrics:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._started_at = time.monotonic()
        self._requests: Counter[tuple[str, str, str]] = Counter()
        self._errors: Counter[str] = Counter()
        self._providers: Counter[tuple[str, str]] = Counter()
        self._latency_seconds_sum = 0.0
        self._latency_seconds_max = 0.0
        self._active_requests = 0

    def request_started(self) -> float:
        with self._lock:
            self._active_requests += 1
        return time.perf_counter()

    def request_finished(
        self,
        *,
        started: float,
        method: str,
        route: str,
        status_code: int,
        error_class: str | None = None,
    ) -> float:
        latency = max(0.0, time.perf_counter() - started)
        status_class = f"{status_code // 100}xx"
        with self._lock:
            self._active_requests = max(0, self._active_requests - 1)
            self._requests[(method, route, status_class)] += 1
            self._latency_seconds_sum += latency
            self._latency_seconds_max = max(self._latency_seconds_max, latency)
            if error_class:
                self._errors[error_class] += 1
        return latency

    def provider_outcome(self, provider: str, outcome: str) -> None:
        safe_provider = provider if provider in {
            "google_vision", "nutritionix", "verified_local", "smtp", "twilio"
        } else "other"
        safe_outcome = outcome if outcome in {
            "success", "not_found", "disabled", "timeout", "rate_limited",
            "auth_error", "temporary_failure", "rejected",
        } else "error"
        with self._lock:
            self._providers[(safe_provider, safe_outcome)] += 1

    def snapshot(self) -> dict[str, object]:
        with self._lock:
            request_count = sum(self._requests.values())
            return {
                "uptime_seconds": round(time.monotonic() - self._started_at, 3),
                "active_requests": self._active_requests,
                "request_count": request_count,
                "latency_seconds_sum": round(self._latency_seconds_sum, 6),
                "latency_seconds_max": round(self._latency_seconds_max, 6),
                "requests": [
                    {
                        "method": method,
                        "route": route,
                        "status_class": status_class,
                        "count": count,
                    }
                    for (method, route, status_class), count
                    in sorted(self._requests.items())
                ],
                "errors": dict(sorted(self._errors.items())),
                "providers": [
                    {"provider": provider, "outcome": outcome, "count": count}
                    for (provider, outcome), count
                    in sorted(self._providers.items())
                ],
            }


runtime_metrics = RuntimeMetrics()
