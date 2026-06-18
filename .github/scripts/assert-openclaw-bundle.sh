#!/usr/bin/env bash
set -euo pipefail

bundle_root="${1:-}"
platform="${2:-windows-x64}"

if [ -z "$bundle_root" ]; then
  echo "usage: $0 <bundle-root-or-app> [platform]" >&2
  exit 2
fi

find_manifest() {
  local root="$1"
  local candidates=(
    "$root/data/flutter_assets/assets/openclaw/bundle_manifest.json"
    "$root/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/openclaw/bundle_manifest.json"
    "$root/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/openclaw/bundle_manifest.json"
    "$root/Frameworks/App.framework/Resources/flutter_assets/assets/openclaw/bundle_manifest.json"
    "$root/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/openclaw/bundle_manifest.json"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  find "$root" -path '*/assets/openclaw/bundle_manifest.json' -type f -print -quit 2>/dev/null || true
}

manifest="$(find_manifest "$bundle_root")"
if [ -z "$manifest" ] || [ ! -f "$manifest" ]; then
  echo "Missing OpenClaw manifest under: $bundle_root" >&2
  exit 1
fi
asset_root="$(cd "$(dirname "$manifest")" && pwd)"
platform_root="$asset_root/$platform"

paths_text="$(python3 - "$manifest" "$platform" <<'PY_PATHS'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = json.load(handle)
platform_name = sys.argv[2]
platform = manifest.get("platforms", {}).get(platform_name, {})
node = platform.get(
    "nodeExecutable",
    "node/node.exe" if platform_name.startswith("windows-") else "node/bin/node",
)
cli = platform.get("cliEntrypoint", "openclaw/openclaw.mjs")
print(node)
print(cli)
PY_PATHS
)"

node_rel="$(printf '%s\n' "$paths_text" | sed -n '1p' | tr -d '\r')"
cli_rel="$(printf '%s\n' "$paths_text" | sed -n '2p' | tr -d '\r')"
node_path="$platform_root/$node_rel"
cli_path="$platform_root/$cli_rel"

if [ ! -f "$node_path" ]; then
  echo "Missing bundled Node executable: $node_path" >&2
  exit 1
fi
if [[ "$platform" != windows-* ]] && [ ! -x "$node_path" ]; then
  echo "Bundled Node executable is not executable: $node_path" >&2
  exit 1
fi
if [ ! -f "$cli_path" ]; then
  echo "Missing bundled OpenClaw CLI: $cli_path" >&2
  exit 1
fi

if [[ "$platform" == macos-* ]]; then
  if ! node_version="$("$node_path" --version 2>&1)"; then
    echo "Bundled macOS Node failed to execute from the app bundle: $node_path" >&2
    echo "$node_version" >&2
    exit 1
  fi
fi

node_count="$(find "$platform_root/node" -type f | wc -l | tr -d ' ')"
openclaw_count="$(find "$platform_root/openclaw" -type f | wc -l | tr -d ' ')"
if [ "$node_count" -lt 20 ] || [ "$openclaw_count" -lt 20 ]; then
  echo "OpenClaw bundle looks incomplete: node files=$node_count openclaw files=$openclaw_count" >&2
  exit 1
fi

bytes="$(du -sk "$platform_root" | awk '{print $1}')"
echo "OpenClaw $platform bundle verified at $platform_root (${bytes} KiB, node=$node_path, cli=$cli_path, node files=$node_count, openclaw files=$openclaw_count)."
