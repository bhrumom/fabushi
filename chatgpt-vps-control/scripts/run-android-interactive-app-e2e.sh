#!/usr/bin/env bash
set -euo pipefail

: "${DEVICE_ID:?DEVICE_ID is required}"
: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${RELEASE_SHA:?RELEASE_SHA is required}"
: "${EVIDENCE_DIR:?EVIDENCE_DIR is required}"
: "${FABUSHI_ACCOUNT_SESSION_FILE:?FABUSHI_ACCOUNT_SESSION_FILE is required}"
: "${FABUSHI_CI_ACCOUNT_SESSION_FILE:?FABUSHI_CI_ACCOUNT_SESSION_FILE is required}"
: "${FABUSHI_CI_TEST_USERNAME:?FABUSHI_CI_TEST_USERNAME is required}"
: "${FABUSHI_CI_TEST_PASSWORD:?FABUSHI_CI_TEST_PASSWORD is required}"

package_id=com.ombhrum.fabushi
external_root="/sdcard/Android/data/$package_id/files"
trace_remote="$external_root/device-gateway-trace.jsonl"
mkdir -p "$EVIDENCE_DIR/steps" "$EVIDENCE_DIR/video" "$EVIDENCE_DIR/release"
control_status="$EVIDENCE_DIR/control-status.txt"
echo initializing > "$control_status"
logcat_pid=""
video_pid=""

pull_trace() {
  adb shell cat "$trace_remote" 2>/dev/null | tr -d '\r' > "$EVIDENCE_DIR/device-gateway-trace.jsonl" || true
}

screenshot() {
  local name="$1"
  adb exec-out screencap -p > "$EVIDENCE_DIR/steps/$name.png" || true
}

stop_recording() {
  adb shell pkill -INT screenrecord >/dev/null 2>&1 || true
  sleep 2
  if [ -n "$video_pid" ]; then
    kill "$video_pid" >/dev/null 2>&1 || true
    wait "$video_pid" >/dev/null 2>&1 || true
  fi
  if [ -n "$logcat_pid" ]; then
    kill "$logcat_pid" >/dev/null 2>&1 || true
    wait "$logcat_pid" >/dev/null 2>&1 || true
  fi
}

finish_evidence() {
  status=$?
  set +e
  pull_trace
  screenshot 999-final
  adb logcat -d -v threadtime > "$EVIDENCE_DIR/logcat-final.txt" 2>&1
  adb shell dumpsys activity activities > "$EVIDENCE_DIR/dumpsys-activities.txt" 2>&1
  adb shell dumpsys package "$package_id" > "$EVIDENCE_DIR/dumpsys-package.txt" 2>&1
  stop_recording

  find "$EVIDENCE_DIR/video" -maxdepth 1 -type f -name 'segment-*.mp4' -size +1k | sort > "$EVIDENCE_DIR/video/segments.txt"
  if [ -s "$EVIDENCE_DIR/video/segments.txt" ]; then
    : > "$EVIDENCE_DIR/video/concat.txt"
    while IFS= read -r segment; do
      printf "file '%s'\n" "$segment" >> "$EVIDENCE_DIR/video/concat.txt"
    done < "$EVIDENCE_DIR/video/segments.txt"
    if command -v ffmpeg >/dev/null 2>&1; then
      ffmpeg -hide_banner -loglevel warning -y -f concat -safe 0 -i "$EVIDENCE_DIR/video/concat.txt" -c copy "$EVIDENCE_DIR/android-session.mp4" > "$EVIDENCE_DIR/ffmpeg.log" 2>&1 || true
    fi
  fi

  final_state="$(cat "$control_status" 2>/dev/null || echo unknown)"
  jq -n \
    --arg status "$final_state" \
    --arg releaseTag "$RELEASE_TAG" \
    --arg releaseSha "$RELEASE_SHA" \
    --arg deviceId "$DEVICE_ID" \
    --arg runId "$GITHUB_RUN_ID" \
    --arg runAttempt "$GITHUB_RUN_ATTEMPT" \
    --arg sourceSha "$GITHUB_SHA" \
    --argjson exitCode "$status" \
    '{schemaVersion:1,platform:"android",status:$status,releaseTag:$releaseTag,releaseSha:$releaseSha,deviceId:$deviceId,runId:$runId,runAttempt:$runAttempt,workflowSourceSha:$sourceSha,scriptExitCode:$exitCode}' \
    > "$EVIDENCE_DIR/report.json"
  exit "$status"
}
trap finish_evidence EXIT

printf '%s\n' \
  "release_tag=$RELEASE_TAG" \
  "release_sha=$RELEASE_SHA" \
  "device_id=$DEVICE_ID" \
  "run_id=$GITHUB_RUN_ID" \
  "run_attempt=$GITHUB_RUN_ATTEMPT" \
  > "$EVIDENCE_DIR/source.env"

ref_sha="$(gh api "repos/$GITHUB_REPOSITORY/git/ref/tags/$RELEASE_TAG" --jq .object.sha)"
test "$ref_sha" = "$RELEASE_SHA"
version="$(gh api "repos/$GITHUB_REPOSITORY/contents/app-version.json?ref=$RELEASE_SHA" --jq .content | base64 -d | jq -r .version)"
case "$RELEASE_TAG" in
  "android-v${version}-"*) ;;
  *) echo "Release tag does not match app-version.json version=$version" >&2; exit 1 ;;
esac

gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json tagName,name,targetCommitish,publishedAt,url > "$EVIDENCE_DIR/release/release.json"
gh release download "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --dir "$EVIDENCE_DIR/release" --pattern 'fabushi-android-*.apk'
gh release download "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --dir "$EVIDENCE_DIR/release" --pattern 'SHA256SUMS.txt'
apk="$(find "$EVIDENCE_DIR/release" -maxdepth 1 -type f -name 'fabushi-android-*.apk' | head -n 1)"
test -n "$apk" && test -f "$apk"
(
  cd "$EVIDENCE_DIR/release"
  sha256sum -c SHA256SUMS.txt
) | tee "$EVIDENCE_DIR/release/checksums.log"

adb wait-for-device
adb shell getprop ro.build.version.release > "$EVIDENCE_DIR/android-version.txt"
adb shell getprop ro.build.version.sdk > "$EVIDENCE_DIR/android-api.txt"
adb logcat -c
adb logcat -v threadtime > "$EVIDENCE_DIR/logcat-live.txt" 2>&1 &
logcat_pid=$!

(
  segment=0
  while true; do
    remote="/sdcard/fabushi-session-${segment}.mp4"
    local_file="$EVIDENCE_DIR/video/segment-$(printf '%04d' "$segment").mp4"
    adb shell rm -f "$remote" >/dev/null 2>&1 || true
    adb shell screenrecord --bit-rate 4000000 --time-limit 180 "$remote" >/dev/null 2>&1 || true
    adb pull "$remote" "$local_file" >/dev/null 2>&1 || true
    adb shell rm -f "$remote" >/dev/null 2>&1 || true
    segment=$((segment + 1))
  done
) &
video_pid=$!

adb install -r "$apk" | tee "$EVIDENCE_DIR/install.log"
screenshot 001-app-installed

test -n "$FABUSHI_CI_TEST_USERNAME"
test -n "$FABUSHI_CI_TEST_PASSWORD"
mkdir -p "$(dirname "$FABUSHI_ACCOUNT_SESSION_FILE")" "$(dirname "$FABUSHI_CI_ACCOUNT_SESSION_FILE")"
chmod 700 "$(dirname "$FABUSHI_ACCOUNT_SESSION_FILE")" "$(dirname "$FABUSHI_CI_ACCOUNT_SESSION_FILE")"
node chatgpt-vps-control/scripts/login-ci-test-account.mjs
node chatgpt-vps-control/scripts/export-ci-app-account-session.mjs
chmod 600 "$FABUSHI_CI_ACCOUNT_SESSION_FILE"

echo authenticated > "$control_status"
adb shell mkdir -p "$external_root"
adb push "$FABUSHI_CI_ACCOUNT_SESSION_FILE" "$external_root/fabushi-ci-session.json" >/dev/null
adb shell rm -f "$trace_remote"

adb shell am force-stop "$package_id" || true
adb shell am start -W \
  -n "$package_id/.MainActivity" \
  --es fabushi.ci.repository "$GITHUB_REPOSITORY" \
  --es fabushi.ci.workflow "$GITHUB_WORKFLOW" \
  --es fabushi.ci.job "$GITHUB_JOB" \
  --es fabushi.ci.run-id "$GITHUB_RUN_ID" \
  --es fabushi.ci.run-attempt "$GITHUB_RUN_ATTEMPT" \
  --es fabushi.ci.sha "$RELEASE_SHA" \
  --es fabushi.ci.runner-name "$RUNNER_NAME" \
  --es fabushi.ci.runner-os "$RUNNER_OS" \
  --es fabushi.ci.runner-arch "$RUNNER_ARCH" \
  --es fabushi.ci.device-name "Fabushi Test Android $GITHUB_RUN_ID/$GITHUB_RUN_ATTEMPT" \
  | tee "$EVIDENCE_DIR/app-launch.txt"

registration_deadline=$((SECONDS + 90))
while [ "$SECONDS" -lt "$registration_deadline" ]; do
  pull_trace
  if jq -e 'select(.phase == "registered")' "$EVIDENCE_DIR/device-gateway-trace.jsonl" >/dev/null 2>&1; then
    echo registered > "$control_status"
    screenshot 002-app-registered
    break
  fi
  sleep 2
done
test "$(cat "$control_status")" = registered

required=(fabushi.app.status fabushi.app.snapshot fabushi.app.find fabushi.app.action fabushi.app.wait fabushi.app.assert)
last=0
deadline=$((SECONDS + 900))
while [ "$SECONDS" -lt "$deadline" ]; do
  pull_trace
  completed="$(jq -c 'select(.phase == "call-completed")' "$EVIDENCE_DIR/device-gateway-trace.jsonl" 2>/dev/null || true)"
  total="$(printf '%s\n' "$completed" | sed '/^$/d' | wc -l | tr -d ' ')"
  while [ "$last" -lt "$total" ]; do
    last=$((last + 1))
    line="$(printf '%s\n' "$completed" | sed -n "${last}p")"
    tool="$(printf '%s' "$line" | jq -r '.toolName // "unknown"' 2>/dev/null || echo unknown)"
    safe_tool="$(printf '%s' "$tool" | tr -cs 'A-Za-z0-9._-' '-')"
    screenshot "$(printf '%03d' $((last + 2)))-${safe_tool}"
  done

  missing=0
  for tool in "${required[@]}"; do
    if ! jq -e --arg tool "$tool" 'select(.phase == "call-completed" and .ok == true and .toolName == $tool)' "$EVIDENCE_DIR/device-gateway-trace.jsonl" >/dev/null 2>&1; then
      missing=1
      break
    fi
  done
  if [ "$missing" -eq 0 ]; then
    echo six-tools-passed > "$control_status"
  fi

  if [ "$(cat "$control_status")" = six-tools-passed ] && jq -e 'select(.phase == "disconnected" and .reason == "logged-out")' "$EVIDENCE_DIR/device-gateway-trace.jsonl" >/dev/null 2>&1; then
    echo passed-logged-out > "$control_status"
    screenshot 998-semantic-matrix-passed
    exit 0
  fi
  sleep 1
done

echo failed-timeout > "$control_status"
echo 'Timed out before external @fabushi test completed the six-tool Android feature matrix and real logout.' >&2
exit 1
