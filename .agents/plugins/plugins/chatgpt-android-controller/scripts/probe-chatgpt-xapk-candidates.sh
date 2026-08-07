#!/usr/bin/env bash
set -euo pipefail

package_name="${CHATGPT_ANDROID_PACKAGE:-com.openai.chatgpt}"
result_file="${CHATGPT_ANDROID_CANDIDATE_RESULT:-${RUNNER_TEMP:-/tmp}/chatgpt-xapk-selected.env}"
# Newest first. Every candidate below has an APKPure build that includes x86_64
# and is subsequently verified against the fixed Google Play App Signing cert.
candidates=(
  '1.2026.020:2602017'
  '1.2026.013:2601320'
  '1.2026.006:2600617'
  '1.2025.364:2536400'
  '1.2025.336:2533628'
)

mkdir -p "$(dirname "$result_file")"
rm -f "$result_file"

for entry in "${candidates[@]}"; do
  version_name=${entry%%:*}
  version_code=${entry##*:}
  bundle="${RUNNER_TEMP:-/tmp}/chatgpt-${version_code}.xapk"

  printf '\n=== Probe ChatGPT %s (%s) ===\n' "$version_name" "$version_code"
  rm -f "$bundle"
  if ! CHATGPT_ANDROID_VERSION_NAME="$version_name" \
       CHATGPT_ANDROID_VERSION_CODE="$version_code" \
       bash scripts/fetch-chatgpt-apkpure.sh "$bundle"; then
    echo "Candidate $version_name download failed; trying older candidate."
    continue
  fi
  if ! bash scripts/verify-chatgpt-xapk.sh "$bundle"; then
    echo "Candidate $version_name identity verification failed; trying older candidate."
    continue
  fi

  adb shell am force-stop "$package_name" >/dev/null 2>&1 || true
  adb uninstall "$package_name" >/dev/null 2>&1 || true
  adb shell am force-stop com.android.vending >/dev/null 2>&1 || true
  adb logcat -c || true

  if ! bash scripts/install-chatgpt-xapk.sh "$bundle"; then
    echo "Candidate $version_name installation failed; trying older candidate."
    continue
  fi

  adb shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
  sleep 10

  pid=$(adb shell pidof "$package_name" 2>/dev/null | tr -d '\r' || true)
  focus=$(adb shell dumpsys window 2>/dev/null \
    | grep -E 'mCurrentFocus|mFocusedApp' \
    | head -n 8 \
    | tr '\n' ' ' || true)
  resumed=$(adb shell dumpsys activity activities 2>/dev/null \
    | grep -m1 'mResumedActivity' \
    | tr -d '\r' || true)

  printf 'Candidate result version=%s pid=%s\n' "$version_name" "${pid:-none}"
  printf 'focus=%s\n' "${focus:-none}"
  printf 'resumed=%s\n' "${resumed:-none}"

  if [[ -n "$pid" ]] && { [[ "$focus" == *"$package_name"* ]] || [[ "$resumed" == *"$package_name"* ]]; }; then
    {
      printf 'CHATGPT_ANDROID_VERSION_NAME=%q\n' "$version_name"
      printf 'CHATGPT_ANDROID_VERSION_CODE=%q\n' "$version_code"
      printf 'CHATGPT_ANDROID_XAPK_PATH=%q\n' "$bundle"
    } > "$result_file"
    echo "Selected usable ChatGPT candidate: $version_name ($version_code)"
    exit 0
  fi

  echo "Candidate $version_name did not remain in the ChatGPT foreground."
  echo 'Relevant logcat tail:'
  adb logcat -d -v brief 2>/dev/null \
    | grep -Ei 'openai|chatgpt|vending|pairip|license|integrity|installer|play' \
    | tail -n 120 || true
done

echo 'No signed x86_64 ChatGPT XAPK candidate stayed usable after ordinary sideload installation.' >&2
exit 1
