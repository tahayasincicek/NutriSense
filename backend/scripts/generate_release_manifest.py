"""Create a traceable release manifest without credentials or deployment claims."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--image-id", required=True)
    parser.add_argument("--sbom", required=True, type=Path)
    parser.add_argument("--openapi", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    payload = {
        "status": "BUILT_NOT_DEPLOYED",
        "version": args.version,
        "revision": args.revision,
        "image_id": args.image_id,
        "sbom_sha256": file_sha256(args.sbom),
        "openapi_sha256": file_sha256(args.openapi),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    args.output.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )
    print("RELEASE_MANIFEST=PASS status=BUILT_NOT_DEPLOYED")


if __name__ == "__main__":
    main()
