#!/usr/bin/env bash
set -euo pipefail

app_path="${1:-}"
if [ -z "$app_path" ]; then
  echo "Usage: $0 path/to/App.app" >&2
  exit 2
fi
if [ ! -d "$app_path" ]; then
  echo "macOS app bundle not found: $app_path" >&2
  exit 1
fi

identity="${MACOS_CODESIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
  identity="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
fi
if [ -z "$identity" ]; then
  echo "Unable to resolve macOS code signing identity." >&2
  exit 1
fi

sign_binary() {
  local path="$1"
  local options=("--force" "--timestamp" "--sign" "$identity")

  if [ -x "$path" ]; then
    options+=("--options" "runtime")
  fi

  echo "Signing $path"
  codesign "${options[@]}" "$path"
}

is_macho() {
  local path="$1"
  file -b "$path" 2>/dev/null | grep -Eq 'Mach-O'
}

while IFS= read -r -d '' binary; do
  if is_macho "$binary"; then
    sign_binary "$binary"
  fi
done < <(
  find "$app_path/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/openclaw" \
    -type f \( -name '*.dylib' -o -name '*.node' -o -perm -111 \) \
    -print0 2>/dev/null || true
)

while IFS= read -r -d '' binary; do
  if is_macho "$binary"; then
    sign_binary "$binary"
  fi
done < <(
  find "$app_path/Contents/Frameworks" \
    -path "$app_path/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/openclaw" -prune -o \
    -type f \( -name '*.dylib' -o -name '*.node' -o -path '*.framework/Versions/*/*' -o -perm -111 \) \
    -print0
)

codesign --force --timestamp --options runtime --sign "$identity" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
