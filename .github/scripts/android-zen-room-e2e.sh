#!/usr/bin/env bash
set -euo pipefail

log_path="${RUNNER_TEMP:-/tmp}/fabushi-android-zen-room-e2e-logcat.txt"

wait_for_android_service() {
  local service_name="$1"

  for _ in $(seq 1 60); do
    if adb shell service check "$service_name" 2>/dev/null | grep -q "found"; then
      return 0
    fi
    sleep 2
  done

  echo "Android service '$service_name' did not become ready in time." >&2
  return 1
}

adb wait-for-device
adb logcat -c || true
wait_for_android_service package
wait_for_android_service activity

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
flutter drive \
  --driver=test_driver/zen_room_buddha_model_e2e_driver.dart \
  --target=integration_test/zen_room_buddha_model_e2e_test.dart \
  --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk \
  -d "$android_device_id" \
  --dart-define=ENV=production
status=$?
set -e

adb logcat -d -t 8000 > "$log_path" || true
exit "$status"
