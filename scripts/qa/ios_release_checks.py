"""Secret-safe source checks for the iOS release boundary.

This checker can run on Windows/Linux. It validates source preparation only;
it does not claim Xcode compilation, signing, archive, or real iPhone evidence.
"""

from __future__ import annotations

import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, needle: str, label: str) -> None:
    if needle not in read_text(path):
        raise SystemExit(f"FAIL {label}: {path}")
    print(f"PASS {label}: {path}")


def forbid(path: str, needle: str, label: str) -> None:
    if needle in read_text(path):
        raise SystemExit(f"FAIL {label}: {path}")
    print(f"PASS {label}: {path}")


def load_plist(path: str) -> dict[str, object]:
    with (ROOT / path).open("rb") as handle:
        return plistlib.load(handle)


def main() -> None:
    required_files = (
        "ios/Runner.xcodeproj/project.pbxproj",
        "ios/Runner.xcworkspace/contents.xcworkspacedata",
        "ios/Runner/Info.plist",
        "ios/Runner/Info-Debug.plist",
        "ios/Podfile",
        "ios/Config/Project.xcconfig",
        "ios/scripts/release_guard.sh",
    )
    for path in required_files:
        if not (ROOT / path).is_file():
            raise SystemExit(f"FAIL required iOS source missing: {path}")
        print(f"PASS required iOS source: {path}")

    production = load_plist("ios/Runner/Info.plist")
    debug = load_plist("ios/Runner/Info-Debug.plist")
    privacy_keys = (
        "NSCameraUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
    )
    for key in privacy_keys:
        value = production.get(key)
        if not isinstance(value, str) or len(value.strip()) < 40:
            raise SystemExit(f"FAIL production privacy string: {key}")
        print(f"PASS production privacy string: {key}")

    forbidden_production_keys = (
        "NSAppTransportSecurity",
        "UIBackgroundModes",
        "NSPhotoLibraryUsageDescription",
        "NSPhotoLibraryAddUsageDescription",
        "NSLocationWhenInUseUsageDescription",
        "NSUserTrackingUsageDescription",
    )
    for key in forbidden_production_keys:
        if key in production:
            raise SystemExit(f"FAIL unnecessary production plist key: {key}")
        print(f"PASS production plist excludes: {key}")

    ats = debug.get("NSAppTransportSecurity")
    if ats != {"NSAllowsLocalNetworking": True}:
        raise SystemExit("FAIL Debug ATS must allow local networking only")
    if "NSLocalNetworkUsageDescription" not in debug:
        raise SystemExit("FAIL Debug local-network explanation is missing")
    print("PASS Debug ATS is local-network-only")

    config = read_text("ios/Config/Project.xcconfig")
    if "NUTRISENSE_BUNDLE_ID = com.example." not in config:
        raise SystemExit("FAIL explicit bundle placeholder/release blocker is missing")
    if "NUTRISENSE_IOS_DEPLOYMENT_TARGET = 13.0" not in config:
        raise SystemExit("FAIL centralized iOS deployment target")
    print("PASS bundle placeholder and deployment target are centralized")

    project = read_text("ios/Runner.xcodeproj/project.pbxproj")
    if project.count("{") != project.count("}"):
        raise SystemExit("FAIL Xcode project has unbalanced braces")
    if project.count('PRODUCT_BUNDLE_IDENTIFIER = "$(NUTRISENSE_BUNDLE_ID)"') != 3:
        raise SystemExit("FAIL Runner bundle identifier is not centralized")
    if (
        project.count(
            'PRODUCT_BUNDLE_IDENTIFIER = "$(NUTRISENSE_BUNDLE_ID).RunnerTests"'
        )
        != 3
    ):
        raise SystemExit("FAIL RunnerTests bundle identifier is not centralized")
    if project.count(
        "baseConfigurationReference = A11CE0032F00000000A11CE0"
    ) != 3:
        raise SystemExit("FAIL project configurations do not inherit central identity")
    if 'INFOPLIST_FILE = "Runner/Info-Debug.plist"' not in project:
        raise SystemExit("FAIL Debug plist is not selected by Xcode")
    if project.count("INFOPLIST_FILE = Runner/Info.plist") != 2:
        raise SystemExit("FAIL Profile/Release must use production Info.plist")
    if "Release Guard" not in project:
        raise SystemExit("FAIL Xcode archive guard is not wired")
    if "DEVELOPMENT_TEAM =" in project:
        raise SystemExit("FAIL Apple Development Team must not be invented")
    print("PASS Xcode identity, plist and signing boundaries")

    podfile = read_text("ios/Podfile")
    for definition in (
        "platform :ios, '13.0'",
        "PERMISSION_CAMERA=1",
        "PERMISSION_MICROPHONE=1",
        "PERMISSION_SPEECH_RECOGNIZER=1",
        "PERMISSION_PHOTOS=0",
        "PERMISSION_LOCATION=0",
        "PERMISSION_NOTIFICATIONS=0",
    ):
        if definition not in podfile:
            raise SystemExit(f"FAIL CocoaPods permission boundary: {definition}")
    print("PASS CocoaPods platform and permission boundaries")

    dependencies = json.loads(read_text(".flutter-plugins-dependencies"))
    ios_plugins = {
        plugin["name"] for plugin in dependencies["plugins"].get("ios", [])
    }
    required_plugins = {
        "camera_avfoundation",
        "flutter_secure_storage_darwin",
        "flutter_tts",
        "permission_handler_apple",
        "speech_to_text",
    }
    missing_plugins = sorted(required_plugins - ios_plugins)
    if missing_plugins:
        raise SystemExit(f"FAIL missing iOS plugins: {', '.join(missing_plugins)}")
    print("PASS required Flutter plugins expose iOS implementations")

    require(
        ".metadata",
        "platform: ios",
        "Flutter migration metadata includes iOS",
    )
    require(
        "docs/ios_release_runbook.md",
        "kaynak hazırlığı tamam, iOS tamamlanmadı",
        "runbook preserves evidence boundary",
    )
    forbid(
        "ios/Runner/Info.plist",
        "Firebase",
        "no unconfigured crash/analytics claim",
    )
    print("IOS_SOURCE_CHECK=PASS status=SOURCE_READY_NOT_IOS_COMPLETE")


if __name__ == "__main__":
    main()
