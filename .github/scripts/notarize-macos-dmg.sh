#!/usr/bin/env bash
set -euo pipefail

dmg_path="${1:-}"
if [ -z "$dmg_path" ] || [ ! -f "$dmg_path" ]; then
  echo "Usage: $0 /path/to/app.dmg" >&2
  exit 2
fi

status_dir="${MACOS_NOTARIZATION_STATUS_DIR:-${GITHUB_WORKSPACE:-$PWD}/macos-notarization-status}"
timeout_minutes="${MACOS_NOTARIZATION_TIMEOUT_MINUTES:-330}"
poll_seconds="${MACOS_NOTARIZATION_POLL_SECONDS:-60}"

case "$timeout_minutes" in
  ''|*[!0-9]*)
    echo "MACOS_NOTARIZATION_TIMEOUT_MINUTES must be a positive integer." >&2
    exit 2
    ;;
esac

case "$poll_seconds" in
  ''|*[!0-9]*)
    echo "MACOS_NOTARIZATION_POLL_SECONDS must be a positive integer." >&2
    exit 2
    ;;
esac

if [ "$timeout_minutes" -le 0 ] || [ "$poll_seconds" -le 0 ]; then
  echo "Notarization timeout and poll interval must be greater than zero." >&2
  exit 2
fi

mkdir -p "$status_dir"

json_value() {
  local file="$1"
  local key="$2"
  /usr/bin/python3 - "$file" "$key" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        value = json.load(handle)
    for part in sys.argv[2].split("."):
        if isinstance(value, dict):
            value = value.get(part, "")
        else:
            value = ""
            break
    print("" if value is None else value)
except Exception:
    print("")
PY
}

identity="${MACOS_CODESIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
  identity="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
fi
if [ -z "$identity" ]; then
  echo "Unable to resolve macOS Developer ID signing identity." >&2
  exit 1
fi

codesign --force --timestamp --sign "$identity" "$dmg_path"

notary_credentials=()
credential_label=""
if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
  notary_credentials=(
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
  )
  credential_label="Apple ID credentials"
elif [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ] && [ -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ] && [ -n "${APP_STORE_CONNECT_API_KEY_BASE64:-}" ]; then
  key_dir="${RUNNER_TEMP:-/tmp}/notarytool/private_keys"
  key_path="$key_dir/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
  mkdir -p "$key_dir"
  printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > "$key_path"
  chmod 600 "$key_path"
  notary_credentials=(
    --key "$key_path"
    --key-id "$APP_STORE_CONNECT_API_KEY_ID"
    --issuer "$APP_STORE_CONNECT_API_ISSUER_ID"
  )
  credential_label="App Store Connect API key"
else
  echo "Skipping notarization because neither Apple ID credentials nor App Store Connect API credentials are configured."
  exit 0
fi

submit_json="$status_dir/notary-submit.json"
info_json="$status_dir/notary-info.json"
log_json="$status_dir/notary-log.json"
summary_md="$status_dir/notary-summary.md"

echo "Submitting $(basename "$dmg_path") to Apple notarization with $credential_label."
xcrun notarytool submit "$dmg_path" "${notary_credentials[@]}" --output-format json > "$submit_json"

submission_id="$(json_value "$submit_json" id)"
if [ -z "$submission_id" ]; then
  echo "Unable to read notarization submission id." >&2
  cat "$submit_json" >&2
  exit 1
fi

{
  echo "## macOS notarization"
  echo ""
  echo "- DMG: \`$(basename "$dmg_path")\`"
  echo "- Submission ID: \`$submission_id\`"
  echo "- Timeout: \`${timeout_minutes}m\`"
  echo "- Poll interval: \`${poll_seconds}s\`"
} > "$summary_md"

deadline=$((SECONDS + timeout_minutes * 60))
while true; do
  if xcrun notarytool info "$submission_id" "${notary_credentials[@]}" --output-format json > "$info_json"; then
    status="$(json_value "$info_json" status)"
    echo "Current notarization status: ${status:-unknown}"

    case "$status" in
      Accepted)
        {
          echo "- Final status: \`Accepted\`"
          echo "- Stapled: \`true\`"
        } >> "$summary_md"
        xcrun stapler staple "$dmg_path"
        if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
          cat "$summary_md" >> "$GITHUB_STEP_SUMMARY"
        fi
        exit 0
        ;;
      Invalid|Rejected)
        xcrun notarytool log "$submission_id" "${notary_credentials[@]}" > "$log_json" || true
        {
          echo "- Final status: \`${status}\`"
          echo "- Notary log: \`$(basename "$log_json")\`"
        } >> "$summary_md"
        if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
          cat "$summary_md" >> "$GITHUB_STEP_SUMMARY"
        fi
        echo "Apple notarization finished with status: $status" >&2
        exit 1
        ;;
    esac
  else
    echo "Unable to read notarization status; retrying until timeout." >&2
  fi

  if [ "$SECONDS" -ge "$deadline" ]; then
    {
      echo "- Final status: \`${status:-unknown}\`"
      echo "- Timed out waiting for Apple notarization."
    } >> "$summary_md"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      cat "$summary_md" >> "$GITHUB_STEP_SUMMARY"
    fi
    echo "Timed out after ${timeout_minutes} minutes waiting for Apple notarization submission $submission_id." >&2
    exit 1
  fi

  remaining=$((deadline - SECONDS))
  sleep_for="$poll_seconds"
  if [ "$remaining" -lt "$sleep_for" ]; then
    sleep_for="$remaining"
  fi
  sleep "$sleep_for"
done
