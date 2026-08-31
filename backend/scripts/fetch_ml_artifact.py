"""Download a declared ML artefact only when its SHA-256 is known.

The command has no demo/fallback model path. Missing URL/checksum, HTTP URLs,
oversized content or checksum drift fail closed.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path


def fetch(*, url: str, sha256: str, destination: Path, max_bytes: int) -> None:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https":
        raise SystemExit("ML_ARTIFACT_FETCH=FAIL only HTTPS artefact URLs are allowed")
    expected = sha256.strip().lower()
    if len(expected) != 64 or any(char not in "0123456789abcdef" for char in expected):
        raise SystemExit("ML_ARTIFACT_FETCH=FAIL SHA-256 must be 64 hexadecimal characters")

    destination.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    total = 0
    temporary_name: str | None = None
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            with tempfile.NamedTemporaryFile(
                dir=destination.parent,
                prefix=f".{destination.name}.",
                delete=False,
            ) as temporary:
                temporary_name = temporary.name
                while chunk := response.read(1024 * 1024):
                    total += len(chunk)
                    if total > max_bytes:
                        raise SystemExit("ML_ARTIFACT_FETCH=FAIL artefact exceeds size limit")
                    digest.update(chunk)
                    temporary.write(chunk)
        if digest.hexdigest() != expected:
            raise SystemExit("ML_ARTIFACT_FETCH=FAIL checksum mismatch")
        os.replace(temporary_name, destination)
        temporary_name = None
    finally:
        if temporary_name:
            Path(temporary_name).unlink(missing_ok=True)
    print(f"ML_ARTIFACT_FETCH=PASS bytes={total} sha256={expected}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--max-bytes", type=int, default=250 * 1024 * 1024)
    args = parser.parse_args()
    fetch(
        url=args.url,
        sha256=args.sha256,
        destination=args.destination,
        max_bytes=args.max_bytes,
    )


if __name__ == "__main__":
    main()
