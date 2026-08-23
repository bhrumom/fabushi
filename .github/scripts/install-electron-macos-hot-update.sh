#!/usr/bin/env bash
set -euo pipefail

payload_dir="${1:-$(cd "$(dirname "$0")" && pwd)}"
app_path="${FABUSHI_APP_PATH:-/Applications/fabushi.app}"
manifest="$payload_dir/manifest.json"
marker="$HOME/Library/Application Support/@fabushi/desktop/installed-source-sha.txt"

[ -f "$manifest" ] || { echo "Missing hot-update manifest: $manifest" >&2; exit 2; }
[ -d "$app_path" ] || { echo "Fabushi is not installed at $app_path; install one full Mac package first." >&2; exit 2; }

read_json() {
  /usr/bin/plutil -extract "$1" raw -o - "$manifest"
}

source_sha="$(read_json sourceSha)"
base_sha="$(read_json baseSha)"
target_arch="$(read_json arch)"
host_included="$(read_json hostIncluded)"
asr_included="$(read_json asrIncluded)"

[ "$(uname -m)" = "$target_arch" ] || { echo "Hot update targets $target_arch, but this Mac is $(uname -m)." >&2; exit 2; }
app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist" 2>/dev/null || true)"
[ "$app_id" = "com.ombhrum.fabushi" ] || { echo "Unexpected app bundle id: ${app_id:-missing}" >&2; exit 2; }

# A Developer ID signed .app is a sealed code bundle. Replacing app.asar or a
# nested executable invalidates the outer signature and can reintroduce macOS
# Keychain authorization prompts. Production installs must therefore move by a
# freshly signed/notarized full package, never by in-place hot patching.
signing_team="$(codesign -dv --verbose=4 "$app_path" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
if [ -n "$signing_team" ] && [ "$signing_team" != "not set" ]; then
  echo "Fabushi at $app_path is a sealed Developer ID build (TeamIdentifier=$signing_team)." >&2
  echo "Refusing to invalidate its signature with a hot update. Install the latest signed/notarized full package instead." >&2
  exit 4
fi

if [ -f "$marker" ]; then
  installed_sha="$(tr -d '[:space:]' < "$marker")"
  if [ "$installed_sha" != "$base_sha" ] && [ "$installed_sha" != "$source_sha" ] && [ "${FABUSHI_HOT_UPDATE_FORCE:-0}" != "1" ]; then
    echo "Installed source $installed_sha does not match hot-update base $base_sha." >&2
    echo "Install the missing incremental update or a fresh full package first." >&2
    exit 3
  fi
elif [ "${FABUSHI_HOT_UPDATE_FORCE:-0}" != "1" ]; then
  echo "Installed source marker is missing; refusing a blind incremental patch." >&2
  echo "Set FABUSHI_HOT_UPDATE_FORCE=1 only if this app is known to match base $base_sha." >&2
  exit 3
fi

[ -f "$payload_dir/app.asar" ] || { echo "Missing app.asar in hot update." >&2; exit 2; }

pkill -TERM -f "$app_path/Contents/MacOS/fabushi" 2>/dev/null || true
pkill -TERM -f "$app_path/Contents/Resources/bin/mahayana-app-host" 2>/dev/null || true
for _ in $(seq 1 40); do
  if ! pgrep -f "$app_path/Contents/MacOS/fabushi" >/dev/null 2>&1; then break; fi
  sleep 0.1
done

atomic_copy() {
  local source="$1"
  local destination="$2"
  local mode="$3"
  local temp="${destination}.hot-update.$$"
  install -m "$mode" "$source" "$temp"
  mv -f "$temp" "$destination"
}

atomic_copy "$payload_dir/app.asar" "$app_path/Contents/Resources/app.asar" 0644

if [ "$host_included" = "true" ]; then
  [ -f "$payload_dir/mahayana-app-host" ] || { echo "Manifest requires Mahayana Host, but it is missing." >&2; exit 2; }
  atomic_copy "$payload_dir/mahayana-app-host" "$app_path/Contents/Resources/bin/mahayana-app-host" 0755
fi

if [ "$asr_included" = "true" ]; then
  [ -d "$payload_dir/asr" ] || { echo "Manifest requires ASR payload, but it is missing." >&2; exit 2; }
  rm -rf "$app_path/Contents/Resources/asr"
  mkdir -p "$app_path/Contents/Resources/asr"
  ditto "$payload_dir/asr" "$app_path/Contents/Resources/asr"
fi

mkdir -p "$(dirname "$marker")"
printf '%s\n' "$source_sha" > "$marker"
open -n "$app_path"
echo "Fabushi hot update installed: $source_sha"
