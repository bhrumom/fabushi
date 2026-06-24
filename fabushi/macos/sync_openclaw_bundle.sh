#!/usr/bin/env bash
set -euo pipefail

if [ "${DACHENG_SYNC_OPENCLAW_RUNTIME:-0}" != "1" ]; then
  echo "OpenClaw runtime sync skipped. Set DACHENG_SYNC_OPENCLAW_RUNTIME=1 to enable."
  exit 0
fi

project_dir="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
repo_root="$(cd "$project_dir/.." && pwd)"
workspace_root="$(cd "$repo_root/.." && pwd)"
platform="${DACHENG_OPENCLAW_PLATFORM:-}"

if [ -z "$platform" ]; then
  case "$(uname -m)" in
    arm64) platform="macos-arm64" ;;
    *) platform="macos-x64" ;;
  esac
fi

app_name="${FULL_PRODUCT_NAME:-${WRAPPER_NAME:-global_dharma_sharing.app}}"
build_products="${TARGET_BUILD_DIR:-${BUILT_PRODUCTS_DIR:-}}"
if [ -z "$build_products" ]; then
  echo "TARGET_BUILD_DIR/BUILT_PRODUCTS_DIR is not set; cannot locate built app." >&2
  exit 1
fi

flutter_assets="$build_products/$app_name/Contents/Frameworks/App.framework/Resources/flutter_assets"
sync_script="$workspace_root/.github/scripts/sync-openclaw-build-assets-v2.sh"
openclaw_assets="$flutter_assets/assets/openclaw/$platform"
entitlements="$project_dir/Runner/OpenClawChild.entitlements"
identity="${OPENCLAW_CODESIGN_IDENTITY:-${EXPANDED_CODE_SIGN_IDENTITY_NAME:-}}"

if [ -z "$identity" ] ||
  [ "$identity" = "\$(EXPANDED_CODE_SIGN_IDENTITY_NAME)" ] ||
  [ "$identity" = "Sign to Run Locally" ]; then
  identity="-"
fi

if [ ! -x "$sync_script" ]; then
  echo "Missing executable OpenClaw sync script: $sync_script" >&2
  exit 1
fi
if [ ! -f "$entitlements" ]; then
  echo "Missing OpenClaw child entitlements: $entitlements" >&2
  exit 1
fi

(
  cd "$repo_root"
  "$sync_script" "$platform" "$flutter_assets"
)
chmod -R u+rwX,go+rX "$openclaw_assets"
xattr -dr com.apple.quarantine "$openclaw_assets" 2>/dev/null || true
xattr -dr com.apple.provenance "$openclaw_assets" 2>/dev/null || true

is_macho_file() {
  /usr/bin/file "$1" | /usr/bin/grep -Eq 'Mach-O'
}

signed_count=0
executable_count=0
while IFS= read -r -d '' file; do
  if ! is_macho_file "$file"; then
    continue
  fi

  options=(--force --sign "$identity")
  if [ -x "$file" ]; then
    options+=(--entitlements "$entitlements")
    executable_count=$((executable_count + 1))
  fi
  /usr/bin/codesign "${options[@]}" "$file"
  signed_count=$((signed_count + 1))
done < <(
  /usr/bin/find "$openclaw_assets" -depth \
    -type f \( -name '*.dylib' -o -name '*.node' -o -perm -111 \) \
    -print0
)

if [ "$signed_count" -eq 0 ] || [ "$executable_count" -eq 0 ]; then
  echo "No signable OpenClaw Mach-O executables found in $openclaw_assets" >&2
  exit 1
fi

echo "Synced and signed OpenClaw $platform payload into $flutter_assets (signed=$signed_count executable=$executable_count identity=$identity)."
