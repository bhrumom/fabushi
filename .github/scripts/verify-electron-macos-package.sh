#!/usr/bin/env bash
set -euo pipefail

app_path="${1:-}"
dmg_path="${2:-}"
if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
  echo "Usage: $0 /path/to/Fabushi.app [/path/to/Fabushi.dmg]" >&2
  exit 2
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")"
[ "$bundle_id" = "com.ombhrum.fabushi" ] || { echo "Unexpected bundle id: $bundle_id" >&2; exit 1; }

codesign --verify --deep --strict --verbose=2 "$app_path"
app_team="$(codesign -dv --verbose=4 "$app_path" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[ -n "$app_team" ] && [ "$app_team" != "not set" ] || { echo 'App is not signed with a stable Apple Team ID.' >&2; exit 1; }

host="$app_path/Contents/Resources/bin/mahayana-app-host"
[ -x "$host" ] || { echo "Missing Mahayana Host: $host" >&2; exit 1; }
codesign --verify --strict --verbose=2 "$host"
host_team="$(codesign -dv --verbose=4 "$host" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[ "$host_team" = "$app_team" ] || { echo "Host Team ID $host_team does not match app Team ID $app_team." >&2; exit 1; }

case "$(uname -m)" in
  arm64) asr_arch=arm64 ;;
  x86_64) asr_arch=x64 ;;
  *) echo "Unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
esac
asr="$app_path/Contents/Resources/asr/darwin-$asr_arch/whisper-cli"
asr_license="$app_path/Contents/Resources/asr/darwin-$asr_arch/LICENSE.whisper.cpp"
[ -x "$asr" ] || { echo "Missing packaged offline ASR executable: $asr" >&2; exit 1; }
[ -f "$asr_license" ] || { echo "Missing packaged offline ASR license: $asr_license" >&2; exit 1; }
codesign --verify --strict --verbose=2 "$asr"
asr_team="$(codesign -dv --verbose=4 "$asr" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[ "$asr_team" = "$app_team" ] || { echo "ASR Team ID $asr_team does not match app Team ID $app_team." >&2; exit 1; }

[ -f "$app_path/Contents/Resources/app.asar" ] || { echo 'Missing app.asar.' >&2; exit 1; }
icon_file="$(/usr/bin/plutil -extract CFBundleIconFile raw -o - "$app_path/Contents/Info.plist" 2>/dev/null || true)"
[ -n "$icon_file" ] || { echo 'Missing CFBundleIconFile.' >&2; exit 1; }
case "$icon_file" in *.icns) ;; *) icon_file="${icon_file}.icns" ;; esac
[ -f "$app_path/Contents/Resources/$icon_file" ] || { echo "Missing packaged app icon: $icon_file" >&2; exit 1; }
/usr/bin/plutil -extract NSMicrophoneUsageDescription raw -o - "$app_path/Contents/Info.plist" >/dev/null
/usr/bin/plutil -extract NSCameraUsageDescription raw -o - "$app_path/Contents/Info.plist" >/dev/null

xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"

if [ -n "$dmg_path" ]; then
  [ -f "$dmg_path" ] || { echo "Missing DMG: $dmg_path" >&2; exit 1; }
  codesign --verify --verbose=2 "$dmg_path"
  xcrun stapler validate "$dmg_path"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg_path"
fi

echo "Verified formal macOS package: TeamIdentifier=$app_team"
