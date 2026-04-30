#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"

android_package="${ANDROID_PACKAGE:-com.ombhrum.fabushi}"

select_ios_runtime() {
  xcrun simctl list runtimes -j | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
runtimes = [r for r in payload.get("runtimes", []) if r.get("isAvailable") and "iOS" in r.get("name", "")]
if not runtimes:
    raise SystemExit("No available iOS simulator runtimes found")
# Prefer the newest available iOS runtime.
runtimes.sort(key=lambda r: tuple(int(p) for p in r.get("version", "0").split(".") if p.isdigit()))
print(runtimes[-1]["identifier"])
'
}

select_ios_device_type() {
  xcrun simctl list devicetypes -j | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
devices = payload.get("devicetypes", [])
preferred = [
    "com.apple.CoreSimulator.SimDeviceType.iPhone-15",
    "com.apple.CoreSimulator.SimDeviceType.iPhone-14",
    "com.apple.CoreSimulator.SimDeviceType.iPhone-13",
]
ids = {d.get("identifier") for d in devices}
for identifier in preferred:
    if identifier in ids:
        print(identifier)
        break
else:
    iphones = [d for d in devices if "iPhone" in d.get("name", "")]
    if not iphones:
        raise SystemExit("No iPhone simulator device types found")
    print(iphones[-1]["identifier"])
'
}

android_install_smoke() {
  local apk_path="build/app/outputs/flutter-apk/app-debug.apk"
  test -s "$apk_path"

  adb wait-for-device
  adb install -r "$apk_path"
  adb shell pm path "$android_package"
  adb shell monkey -p "$android_package" -c android.intent.category.LAUNCHER 1
  sleep 15
  adb shell pidof "$android_package"
  adb logcat -d -t 2000 > "${RUNNER_TEMP:-/tmp}/fabushi-android-logcat.txt" || true
}

ios_install_smoke() {
  local runtime device_type udid app_path bundle_id screenshot_path

  runtime="$(select_ios_runtime)"
  device_type="$(select_ios_device_type)"
  udid="$(xcrun simctl create 'Fabushi CI iPhone' "$device_type" "$runtime")"

  cleanup() {
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b

  app_path="$(find build/ios/iphonesimulator -name Runner.app -type d | head -n 1)"
  test -d "$app_path"

  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_path/Info.plist")"
  test -n "$bundle_id"

  xcrun simctl install "$udid" "$app_path"
  xcrun simctl get_app_container "$udid" "$bundle_id" app
  xcrun simctl launch "$udid" "$bundle_id"
  sleep 15

  screenshot_path="${RUNNER_TEMP:-/tmp}/fabushi-ios-simulator.png"
  xcrun simctl io "$udid" screenshot "$screenshot_path" || true
  test -s "$screenshot_path"
}

case "$platform" in
  android)
    android_install_smoke
    ;;
  ios)
    ios_install_smoke
    ;;
  *)
    echo "Usage: $0 android|ios" >&2
    exit 64
    ;;
esac
