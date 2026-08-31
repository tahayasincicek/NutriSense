"""Generate a deterministic CycloneDX dependency SBOM from the hash lock."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

PACKAGE = re.compile(r"^([A-Za-z0-9_.-]+)==([^\s\\]+)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args()

    components = []
    for line in args.lock.read_text(encoding="utf-8").splitlines():
        match = PACKAGE.match(line)
        if not match:
            continue
        name, version = match.groups()
        normalized = name.lower().replace("_", "-")
        components.append(
            {
                "type": "library",
                "name": normalized,
                "version": version,
                "purl": f"pkg:pypi/{normalized}@{version}",
            }
        )
    components.sort(key=lambda item: item["purl"])
    payload = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "serialNumber": f"urn:uuid:nutrisense-{args.revision}",
        "version": 1,
        "metadata": {
            "component": {
                "type": "application",
                "name": "nutrisense-backend",
                "version": args.version,
                "properties": [
                    {"name": "git:revision", "value": args.revision},
                    {"name": "source:lock", "value": str(args.lock)},
                ],
            }
        },
        "components": components,
    }
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"SBOM=PASS components={len(components)}")


if __name__ == "__main__":
    main()
