"""FastAPI OpenAPI çıktısını üretir veya checked-in sözleşmeyle karşılaştırır."""

import argparse
import json
from pathlib import Path
import sys

BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))

from app.main import app


def serialized_openapi() -> str:
    return json.dumps(
        app.openapi(),
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "path",
        nargs="?",
        default="../contracts/openapi.json",
        type=Path,
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = serialized_openapi()
    target = args.path.resolve()

    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != expected:
            print(
                f"OpenAPI drift: {target} güncel değil. "
                "python scripts/export_openapi.py komutunu çalıştırın.",
                file=sys.stderr,
            )
            return 1
        print(f"OpenAPI drift kontrolü geçti: {target}")
        return 0

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(expected, encoding="utf-8")
    print(f"OpenAPI yazıldı: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
