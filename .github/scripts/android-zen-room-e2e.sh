#!/usr/bin/env bash
set -euo pipefail

log_path="${RUNNER_TEMP:-/tmp}/fabushi-android-zen-room-e2e-logcat.txt"

adb wait-for-device
adb logcat -c || true

flutter devices
android_device_id="$(
  adb devices \
    | awk '/^(emulator|[0-9A-Za-z._:-]+)[[:space:]]+device$/ { print $1; exit }'
)"

if [[ -z "$android_device_id" ]]; then
  echo "No Android emulator/device is available for the Zen room E2E run." >&2
  exit 1
fi

echo "Running Zen room E2E on Android device: $android_device_id"

set +e
flutter test integration_test/zen_room_buddha_model_e2e_test.dart \
  -d "$android_device_id" \
  --dart-define=ENV=production
status=$?
set -e

adb logcat -d -t 8000 > "$log_path" || true
exit "$status"
