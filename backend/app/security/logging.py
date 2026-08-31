"""Central log redaction for credentials, contact data and image payloads."""

from __future__ import annotations

import logging
import json
import re
from datetime import datetime, timezone


_REDACTIONS = (
    (re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+"), "Bearer [REDACTED]"),
    (
        re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b"),
        "[REDACTED_JWT]",
    ),
    (
        re.compile(
            r"(?i)(password|passwd|secret|token|api[_-]?key)"
            r"(\s*[=:]\s*[\"']?)[^,\s}\"']+"
        ),
        r"\1\2[REDACTED]",
    ),
    (
        re.compile(r"(?i)data:image/[a-z0-9.+-]+;base64,[A-Za-z0-9+/=]+"),
        "[REDACTED_IMAGE]",
    ),
    (
        re.compile(r"\b[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
        "[REDACTED_EMAIL]",
    ),
    (
        re.compile(r"(?<!\w)\+?[1-9][0-9 ()-]{7,}[0-9](?!\w)"),
        "[REDACTED_PHONE]",
    ),
    (re.compile(r"\b[A-Za-z0-9+/]{120,}={0,2}\b"), "[REDACTED_BASE64]"),
)


def redact_text(value: object) -> str:
    result = str(value)
    for pattern, replacement in _REDACTIONS:
        result = pattern.sub(replacement, result)
    return result


class SensitiveDataFilter(logging.Filter):
    """Redact a record before it reaches a configured handler."""

    def filter(self, record: logging.LogRecord) -> bool:
        message = redact_text(record.getMessage())
        if record.exc_info:
            exception = record.exc_info[1]
            message = f"{message} exception_type={type(exception).__name__}"
            # Exception messages and tracebacks may contain request bodies or SQL values.
            record.exc_info = None
            record.exc_text = None
        record.msg = message
        record.args = ()
        return True


class PrivacySafeJsonFormatter(logging.Formatter):
    """Emit a small structured envelope without arbitrary record attributes."""

    def format(self, record: logging.LogRecord) -> str:
        return json.dumps(
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "level": record.levelname,
                "logger": record.name,
                "event": redact_text(record.getMessage()),
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )


def configure_secure_logging(
    *,
    debug: bool,
    level: str = "INFO",
    log_format: str = "json",
) -> None:
    resolved_level = logging.DEBUG if debug else getattr(logging, level.upper())
    logging.basicConfig(
        level=resolved_level,
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        force=True,
    )
    root = logging.getLogger()
    for handler in root.handlers:
        if log_format == "json":
            handler.setFormatter(PrivacySafeJsonFormatter())
        if not any(isinstance(item, SensitiveDataFilter) for item in handler.filters):
            handler.addFilter(SensitiveDataFilter())
