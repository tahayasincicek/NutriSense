"""Fail-closed static checks for Android release boundaries.

The script prints file names and rule names only; it never reads or emits
secret values.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def require(path: str, needle: str, label: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    if needle not in text:
        raise SystemExit(f"FAIL {label}: {path}")
    print(f"PASS {label}: {path}")


def forbid_tree(root: str, needles: tuple[str, ...], label: str) -> None:
    violations: list[str] = []
    for path in (ROOT / root).rglob("*"):
        if path.suffix not in {".dart", ".kt", ".java", ".xml"} or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if any(needle in text for needle in needles):
            violations.append(path.relative_to(ROOT).as_posix())
    if violations:
        raise SystemExit(f"FAIL {label}: {', '.join(sorted(violations))}")
    print(f"PASS {label}")


def main() -> None:
    require(
        "android/app/src/main/AndroidManifest.xml",
        'android:usesCleartextTraffic="false"',
        "release cleartext disabled",
    )
    require(
        "android/app/src/main/res/xml/network_security_config.xml",
        'cleartextTrafficPermitted="false"',
        "base network policy denies cleartext",
    )
    require(
        "android/app/build.gradle.kts",
        'getDefaultProguardFile("proguard-android-optimize.txt")',
        "R8 release rules enabled",
    )
    require(
        "android/app/build.gradle.kts",
        "key.properties is missing",
        "release signing fails without local key properties",
    )
    require(
        "lib/core/config/app_config.dart",
        "Staging and production API_BASE_URL must use HTTPS.",
        "public environment config enforces TLS",
    )
    forbid_tree(
        "lib",
        ("badCertificateCallback", "HttpOverrides.global", "setTrustedCertificatesBytes"),
        "no TLS certificate bypass in mobile code",
    )


if __name__ == "__main__":
    main()
