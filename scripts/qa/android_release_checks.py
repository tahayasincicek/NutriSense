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


def forbid(path: str, needle: str, label: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    if needle in text:
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
    manifest = "android/app/src/main/AndroidManifest.xml"
    build_file = "android/app/build.gradle.kts"

    for permission in ("INTERNET", "CAMERA", "RECORD_AUDIO"):
        require(
            manifest,
            f'android.permission.{permission}"',
            f"required {permission} permission declared",
        )
    for hardware in ("camera", "microphone"):
        require(
            manifest,
            f'android.hardware.{hardware}" android:required="false"',
            f"{hardware} hardware remains optional",
        )
    forbid(
        manifest,
        "android.permission.POST_NOTIFICATIONS",
        "notification permission absent until runtime feature exists",
    )
    require(
        manifest,
        'android:usesCleartextTraffic="false"',
        "release cleartext disabled",
    )
    require(
        manifest,
        'android:roundIcon="@mipmap/ic_launcher_round"',
        "adaptive round icon configured",
    )
    require(
        manifest,
        'android:allowBackup="false"',
        "Android backup disabled",
    )
    require(
        manifest,
        'android:fullBackupContent="@xml/backup_rules"',
        "legacy backup exclusions configured",
    )
    require(
        manifest,
        'android:dataExtractionRules="@xml/data_extraction_rules"',
        "Android 12+ extraction exclusions configured",
    )
    for backup_file in (
        "android/app/src/main/res/xml/backup_rules.xml",
        "android/app/src/main/res/xml/data_extraction_rules.xml",
    ):
        require(backup_file, 'domain="database"', "database backup excluded")
        require(backup_file, 'domain="sharedpref"', "shared preferences backup excluded")
    require(
        "android/app/src/main/res/xml/network_security_config.xml",
        'cleartextTrafficPermitted="false"',
        "base network policy denies cleartext",
    )
    for local_host in ("10.0.2.2", "127.0.0.1", "localhost"):
        forbid(
            "android/app/src/main/res/xml/network_security_config.xml",
            local_host,
            "base network policy contains no development host",
        )
        require(
            "android/app/src/devDebug/res/xml/network_security_config.xml",
            local_host,
            "devDebug network policy contains expected local host",
        )
    require(
        "android/app/src/devDebug/AndroidManifest.xml",
        'android:usesCleartextTraffic="true"',
        "cleartext override limited to devDebug overlay",
    )
    for value in (
        "val nutriSenseCompileSdk = 36",
        "val nutriSenseMinSdk = 24",
        "val nutriSenseTargetSdk = 36",
    ):
        require(build_file, value, "Android SDK contract pinned")
    for flavor in ('create("dev")', 'create("staging")', 'create("prod")'):
        require(build_file, flavor, "environment flavor configured")
    require(
        build_file,
        'getDefaultProguardFile("proguard-android-optimize.txt")',
        "R8 release rules enabled",
    )
    require(
        build_file,
        'desugar_jdk_libs:2.1.5',
        "core library desugaring dependency pinned",
    )
    require(
        build_file,
        "key.properties is missing",
        "release signing fails without local key properties",
    )
    require(
        build_file,
        'startsWith("com.example.")',
        "placeholder application ID blocks release",
    )
    require(
        build_file,
        'signingConfig = signingConfigs.findByName("release")',
        "release uses only release signing configuration",
    )
    forbid(
        build_file,
        'signingConfig = signingConfigs.getByName("debug")',
        "release never selects debug signing",
    )
    for ignored in ("/android/key.properties", "*.jks", "*.keystore"):
        require(".gitignore", ignored, "signing material ignored by Git")
    require(
        "android/app/lint.xml",
        'id="PropertyEscape"',
        "lint exception is limited to generated local properties",
    )
    forbid(
        build_file,
        "lint-baseline",
        "Android lint failures are not hidden by a baseline",
    )
    require(
        "lib/core/config/app_config.dart",
        "Staging and production API_BASE_URL must use HTTPS.",
        "public environment config enforces TLS",
    )
    require(
        "lib/core/config/app_config.dart",
        "diagnosticLoggingEnabled",
        "environment logging policy is centralized",
    )
    forbid_tree(
        "lib",
        ("badCertificateCallback", "HttpOverrides.global", "setTrustedCertificatesBytes"),
        "no TLS certificate bypass in mobile code",
    )


if __name__ == "__main__":
    main()
