#!/usr/bin/env bash
set -euo pipefail

bundle_root="${1:-}"
platform="${2:-windows-x64}"

if [ -z "$bundle_root" ]; then
  echo "usage: $0 <bundle-root> [platform]" >&2
  exit 2
fi

asset_root="$bundle_root/data/flutter_assets/assets/openclaw/$platform"
manifest="$bundle_root/data/flutter_assets/assets/openclaw/bundle_manifest.json"

if [ ! -f "$manifest" ]; then
  echo "Missing OpenClaw manifest: $manifest" >&2
  exit 1
fi

readarray -t paths < <(python3 - "$manifest" "$platform" <<'PY_PATHS'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = json.load(handle)
platform = manifest.get("platforms", {}).get(sys.argv[2], {})
node = platform.get(
    "nodeExecutable",
    "node/node.exe" if sys.argv[2].startswith("windows-") else "node/bin/node",
)
cli = platform.get("cliEntrypoint", "openclaw/openclaw.mjs")
print(node)
print(cli)
PY_PATHS
)

node_rel="${paths[0]%$'\r'}"
cli_rel="${paths[1]%$'\r'}"
node_path="$asset_root/$node_rel"
cli_path="$asset_root/$cli_rel"

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

node_count="$(find "$asset_root/node" -type f | wc -l | tr -d ' ')"
openclaw_count="$(find "$asset_root/openclaw" -type f | wc -l | tr -d ' ')"
if [ "$node_count" -lt 20 ] || [ "$openclaw_count" -lt 20 ]; then
  echo "OpenClaw bundle looks incomplete: node files=$node_count openclaw files=$openclaw_count" >&2
  exit 1
fi

bytes="$(du -sk "$asset_root" | awk '{print $1}')"
echo "OpenClaw $platform bundle verified at $asset_root (${bytes} KiB, node=$node_path, cli=$cli_path, node files=$node_count, openclaw files=$openclaw_count)."
