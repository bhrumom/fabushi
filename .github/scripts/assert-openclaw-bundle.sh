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
node_path="$asset_root/node/node.exe"
cli_path="$asset_root/openclaw/bin/openclaw.js"

if [ ! -f "$manifest" ]; then
  echo "Missing OpenClaw manifest: $manifest" >&2
  exit 1
fi
if [ ! -f "$node_path" ]; then
  echo "Missing bundled Node executable: $node_path" >&2
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
echo "OpenClaw $platform bundle verified at $asset_root (${bytes} KiB, node files=$node_count, openclaw files=$openclaw_count)."
