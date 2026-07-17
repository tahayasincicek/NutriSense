from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
import urllib.request
from pathlib import Path


def fetch(url: str, expected_sha256: str, output: Path) -> None:
    if not url.startswith("https://"):
        raise ValueError("Only HTTPS artifact URLs are accepted")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        raise ValueError("Expected SHA-256 must be 64 lowercase hexadecimal characters")
    output.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as temporary:
        temp_path = Path(temporary.name)
        with urllib.request.urlopen(url, timeout=60) as response:  # nosec: HTTPS + mandatory checksum
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                temporary.write(chunk)
    if digest.hexdigest() != expected_sha256:
        temp_path.unlink(missing_ok=True)
        raise ValueError("Artifact checksum mismatch; file was not installed")
    temp_path.replace(output)


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch a private ML artifact with mandatory checksum verification")
    parser.add_argument("--url", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    fetch(args.url, args.sha256, args.output)
    print(json.dumps({"status": "installed", "output": args.output.as_posix(), "sha256": args.sha256}))


if __name__ == "__main__":
    main()
