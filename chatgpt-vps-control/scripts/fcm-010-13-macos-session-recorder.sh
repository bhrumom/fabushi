#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIDEO_TOOL="$SCRIPT_DIR/fcm-010-13-macos-session-video.swift"
ASSISTANT_DRIVER='AppleM2ScalerParavirtDriver'
CAPTURE_INTERVAL_SECONDS="${FCM_MACOS_RECORDING_INTERVAL_SECONDS:-1}"
MIN_VIDEO_BYTES="${FCM_MACOS_RECORDING_MIN_BYTES:-100000}"

usage() {
  echo "usage: $0 preflight|start|capture-loop|assert-live|stop|verify <evidence-dir>" >&2
  exit 64
}

require_macos_tools() {
  test "$(uname -s)" = Darwin
  test -x /usr/sbin/screencapture
  test -x /usr/sbin/system_profiler
  test -x /usr/sbin/ioreg
  command -v swift >/dev/null
  command -v jq >/dev/null
  [[ "$MIN_VIDEO_BYTES" =~ ^[0-9]+$ ]]
  test "$MIN_VIDEO_BYTES" -gt 0
  test -s "$VIDEO_TOOL"
}

frame_count() {
  local frames="$1/session-frames"
  if ! test -d "$frames"; then
    echo 0
    return
  fi
  /usr/bin/find "$frames" -type f -name '*.jpg' -print | wc -l | tr -d ' '
}

validate_video() {
  local video="$1"
  local output="$2"
  test -s "$video"
  swift "$VIDEO_TOOL" validate "$video" > "$output" 2>&1
  grep -Fq 'playable=true' "$output"
  grep -Fq 'first_sample=decoded' "$output"
}

collect_display_environment() {
  local evidence="$1"
  local profiler="$evidence/recorder-system-profiler-display.txt"
  local driver_ioreg="$evidence/recorder-ioreg-driver.txt"
  local display_ioreg="$evidence/recorder-ioreg-display-lines.txt"
  local combined="$evidence/recorder-display-environment.txt"

  /usr/sbin/system_profiler SPDisplaysDataType > "$profiler" 2>&1 || true
  /usr/sbin/ioreg -r -c "$ASSISTANT_DRIVER" -l > "$driver_ioreg" 2>&1 || true
  /usr/sbin/ioreg -lw0 2>&1 \
    | grep -E 'AppleM2ScalerParavirtDriver|AppleParavirt|IODisplay|DisplayVendorID|DisplayProductID|framebuffer|Framebuffer' \
    > "$display_ioreg" || true

  {
    echo 'schema=fabushi.macos-session-recorder-environment.v1'
    echo "uname=$(uname -a)"
    echo "runner_os=${RUNNER_OS:-unknown}"
    echo "runner_arch=${RUNNER_ARCH:-unknown}"
    echo '--- sw_vers ---'
    /usr/bin/sw_vers 2>&1 || true
    echo '--- system_profiler SPDisplaysDataType ---'
    cat "$profiler"
    echo '--- ioreg exact driver class ---'
    cat "$driver_ioreg"
    echo '--- ioreg display-related lines ---'
    cat "$display_ioreg"
  } > "$combined"
  test -s "$combined"
}

native_probe() {
  local evidence="$1"
  local video="$evidence/native-recorder-probe.mov"
  local log="$evidence/native-recorder-probe.log"
  local validation="$evidence/native-recorder-probe-validation.txt"
  rm -f "$video" "$log" "$validation"

  set +e
  /usr/sbin/screencapture -v -V 2 -D 1 "$video" > "$log" 2>&1 &
  local pid=$!
  local finished=false
  for _ in $(seq 1 10); do
    if ! kill -0 "$pid" 2>/dev/null; then
      finished=true
      break
    fi
    sleep 1
  done
  if test "$finished" != true; then
    echo 'native probe exceeded its bounded completion window' >> "$log"
    kill -INT "$pid" 2>/dev/null || true
    sleep 1
    kill -TERM "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null
  local native_exit=$?
  set -e
  printf '%s\n' "$native_exit" > "$evidence/native-recorder-probe-exit.txt"

  if test -s "$video" && validate_video "$video" "$validation"; then
    printf '%s\n' true > "$evidence/native-recorder-probe-playable.txt"
  else
    printf '%s\n' false > "$evidence/native-recorder-probe-playable.txt"
    test -s "$validation" || echo 'playable=false native probe produced no decodable movie' > "$validation"
  fi
}

fallback_probe() {
  local evidence="$1"
  local frames="$evidence/fallback-recorder-probe-frames"
  local video="$evidence/fallback-recorder-probe.mov"
  local validation="$evidence/fallback-recorder-probe-validation.txt"
  rm -rf "$frames"
  rm -f "$video" "$validation"
  mkdir -p "$frames"
  for index in 0 1 2; do
    local frame="$frames/$(printf '%03d' "$index").jpg"
    if ! /usr/sbin/screencapture -x -D 1 -t jpg "$frame" > "$evidence/fallback-recorder-probe-screencapture-$index.log" 2>&1; then
      echo "fallback screenshot capture failed at probe frame $index" >&2
      return 51
    fi
    test -s "$frame"
    sleep 0.2
  done
  swift "$VIDEO_TOOL" encode "$frames" "$video" 1 > "$validation" 2>&1
  validate_video "$video" "$evidence/fallback-recorder-probe-revalidation.txt"
  printf '%s\n' true > "$evidence/fallback-recorder-probe-playable.txt"
  rm -rf "$frames"
}

preflight() {
  local evidence="$1"
  require_macos_tools
  mkdir -p "$evidence"
  collect_display_environment "$evidence"

  local paravirt=false profiler_present=false
  if grep -Fq "$ASSISTANT_DRIVER" "$evidence/recorder-display-environment.txt"; then
    paravirt=true
  fi
  if test -s "$evidence/recorder-system-profiler-display.txt"; then
    profiler_present=true
  fi
  printf '%s\n' "$paravirt" > "$evidence/apple-m2-scaler-paravirt-driver.txt"

  native_probe "$evidence"
  if ! fallback_probe "$evidence"; then
    printf '%s\n' false > "$evidence/fallback-recorder-probe-playable.txt"
    jq -n \
      --arg schema 'fabushi.macos-session-recorder-preflight.v1' \
      --arg runnerOs "${RUNNER_OS:-$(uname -s)}" \
      --arg runnerArch "${RUNNER_ARCH:-$(uname -m)}" \
      --arg driver "$ASSISTANT_DRIVER" \
      --arg nativePlayable "$(cat "$evidence/native-recorder-probe-playable.txt")" \
      --argjson paravirt "$paravirt" \
      --argjson profilerPresent "$profiler_present" \
      '{schema:$schema,runnerOs:$runnerOs,runnerArch:$runnerArch,displayDriver:$driver,appleM2ScalerParavirtDriver:$paravirt,systemProfilerDisplayDataPresent:$profilerPresent,nativeRecorderPlayable:($nativePlayable == "true"),fallbackRecorderPlayable:false,selectedMode:"none",failClosed:true}' \
      > "$evidence/recorder-preflight.json"
    echo 'No verified playable recording backend is available on this runner; refusing to continue.' >&2
    return 52
  fi

  local native_playable fallback_playable
  native_playable="$(cat "$evidence/native-recorder-probe-playable.txt")"
  fallback_playable="$(cat "$evidence/fallback-recorder-probe-playable.txt")"
  test "$fallback_playable" = true

  jq -n \
    --arg schema 'fabushi.macos-session-recorder-preflight.v1' \
    --arg runnerOs "${RUNNER_OS:-$(uname -s)}" \
    --arg runnerArch "${RUNNER_ARCH:-$(uname -m)}" \
    --arg driver "$ASSISTANT_DRIVER" \
    --arg nativePlayable "$native_playable" \
    --arg fallbackPlayable "$fallback_playable" \
    --arg selectedMode 'frame-avassetwriter' \
    --argjson paravirt "$paravirt" \
    --argjson profilerPresent "$profiler_present" \
    '{schema:$schema,runnerOs:$runnerOs,runnerArch:$runnerArch,displayDriver:$driver,appleM2ScalerParavirtDriver:$paravirt,systemProfilerDisplayDataPresent:$profilerPresent,nativeRecorderPlayable:($nativePlayable == "true"),fallbackRecorderPlayable:($fallbackPlayable == "true"),selectedMode:$selectedMode,failClosed:true}' \
    > "$evidence/recorder-preflight.json"

  jq -e '.failClosed == true and .selectedMode == "frame-avassetwriter" and .fallbackRecorderPlayable == true' \
    "$evidence/recorder-preflight.json" >/dev/null
  if test "$paravirt" = true && test "$native_playable" != true; then
    echo "$ASSISTANT_DRIVER detected; native whole-session video is not trusted, verified frame/AVAssetWriter recorder selected." \
      | tee "$evidence/recorder-selection.txt"
  else
    echo 'Verified frame/AVAssetWriter recorder selected after bounded native recorder probe.' \
      | tee "$evidence/recorder-selection.txt"
  fi
}

capture_loop() {
  local evidence="$1"
  local frames="$evidence/session-frames"
  mkdir -p "$frames"
  rm -f "$evidence/recorder.failed" "$evidence/recorder.stop"
  local index=0
  while ! test -f "$evidence/recorder.stop"; do
    local frame="$frames/$(printf '%07d' "$index").jpg"
    if ! /usr/sbin/screencapture -x -D 1 -t jpg "$frame" > "$evidence/session-recorder-last-screencapture.log" 2>&1; then
      echo "screencapture failed at frame $index" > "$evidence/recorder.failed"
      exit 41
    fi
    if ! test -s "$frame"; then
      echo "empty frame at index $index" > "$evidence/recorder.failed"
      exit 42
    fi
    index=$((index + 1))
    printf '%s\n' "$index" > "$evidence/recorder-frame-count.txt"
    sleep "$CAPTURE_INTERVAL_SECONDS"
  done
}

assert_live() {
  local evidence="$1"
  test -s "$evidence/session-recorder.pid"
  local pid
  pid="$(cat "$evidence/session-recorder.pid")"
  kill -0 "$pid"
  if test -s "$evidence/recorder.failed"; then
    cat "$evidence/recorder.failed" >&2
    cat "$evidence/session-recorder-last-screencapture.log" >&2 2>/dev/null || true
    exit 1
  fi
  local count
  count="$(frame_count "$evidence")"
  test "$count" -ge 2
  printf 'recorder_live=true pid=%s frames=%s\n' "$pid" "$count"
}

start() {
  local evidence="$1"
  preflight "$evidence"
  rm -rf "$evidence/session-frames"
  rm -f "$evidence/recorder.stop" "$evidence/recorder.failed" "$evidence/macos-session.mov"
  mkdir -p "$evidence/session-frames"
  date +%s > "$evidence/recorder-started-epoch.txt"
  RUNNER_TRACKING_ID= nohup bash "$0" capture-loop "$evidence" \
    > "$evidence/session-recorder-capture.log" 2>&1 &
  local pid=$!
  printf '%s\n' "$pid" > "$evidence/session-recorder.pid"
  sleep 3
  assert_live "$evidence"
}

stop() {
  local evidence="$1"
  require_macos_tools
  test -s "$evidence/session-recorder.pid"
  local pid
  pid="$(cat "$evidence/session-recorder.pid")"
  touch "$evidence/recorder.stop"
  for _ in $(seq 1 30); do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo 'recorder capture loop did not stop within 30 seconds' > "$evidence/recorder.failed"
    kill -TERM "$pid" 2>/dev/null || true
    exit 43
  fi
  if test -s "$evidence/recorder.failed"; then
    cat "$evidence/recorder.failed" >&2
    cat "$evidence/session-recorder-last-screencapture.log" >&2 2>/dev/null || true
    exit 1
  fi

  local count started ended duration movie_bytes
  count="$(frame_count "$evidence")"
  test "$count" -ge 3
  started="$(cat "$evidence/recorder-started-epoch.txt")"
  ended="$(date +%s)"
  duration=$((ended - started))
  if test "$duration" -lt 1; then duration=1; fi

  swift "$VIDEO_TOOL" encode "$evidence/session-frames" "$evidence/macos-session.mov" "$duration" \
    > "$evidence/macos-session-encode-validation.txt" 2>&1
  validate_video "$evidence/macos-session.mov" "$evidence/macos-session-playability.txt"
  movie_bytes="$(stat -f %z "$evidence/macos-session.mov")"
  test "$movie_bytes" -gt "$MIN_VIDEO_BYTES"

  local paravirt native_playable
  paravirt="$(cat "$evidence/apple-m2-scaler-paravirt-driver.txt")"
  native_playable="$(cat "$evidence/native-recorder-probe-playable.txt")"
  jq -n \
    --arg schema 'fabushi.macos-session-recorder.v1' \
    --arg mode 'frame-avassetwriter' \
    --argjson frames "$count" \
    --argjson durationSeconds "$duration" \
    --argjson movieBytes "$movie_bytes" \
    --argjson minimumMovieBytes "$MIN_VIDEO_BYTES" \
    --arg nativePlayable "$native_playable" \
    --argjson paravirt "$paravirt" \
    --arg movie 'macos-session.mov' \
    '{schema:$schema,mode:$mode,frames:$frames,durationSeconds:$durationSeconds,movieBytes:$movieBytes,minimumMovieBytes:$minimumMovieBytes,appleM2ScalerParavirtDriver:$paravirt,nativeRecorderPlayable:($nativePlayable == "true"),movie:$movie,playable:true,firstSampleDecoded:true,failClosed:true}' \
    > "$evidence/recorder-final.json"
  rm -rf "$evidence/session-frames"
}

verify() {
  local evidence="$1"
  require_macos_tools
  test -s "$evidence/recorder-preflight.json"
  test -s "$evidence/recorder-final.json"
  jq -e '.failClosed == true and .fallbackRecorderPlayable == true and .selectedMode == "frame-avassetwriter"' \
    "$evidence/recorder-preflight.json" >/dev/null
  jq -e '.failClosed == true and .mode == "frame-avassetwriter" and .playable == true and .firstSampleDecoded == true and .frames >= 3 and .durationSeconds > 0 and .movieBytes > .minimumMovieBytes' \
    "$evidence/recorder-final.json" >/dev/null
  test -s "$evidence/macos-session.mov"
  test "$(stat -f %z "$evidence/macos-session.mov")" -gt "$MIN_VIDEO_BYTES"
  validate_video "$evidence/macos-session.mov" "$evidence/macos-session-final-validation.txt"
}

command="${1:-}"
evidence="${2:-}"
test -n "$command" && test -n "$evidence" || usage
case "$command" in
  preflight) preflight "$evidence" ;;
  start) start "$evidence" ;;
  capture-loop) capture_loop "$evidence" ;;
  assert-live) assert_live "$evidence" ;;
  stop) stop "$evidence" ;;
  verify) verify "$evidence" ;;
  *) usage ;;
esac
