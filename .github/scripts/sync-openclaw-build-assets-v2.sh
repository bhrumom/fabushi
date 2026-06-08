#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
build_assets="${2:-}"

if [ -z "$platform" ] || [ -z "$build_assets" ]; then
  echo "usage: $0 <platform> <build-flutter-assets-dir>" >&2
  exit 2
fi

source_dir="assets/openclaw/$platform"
target_dir="$build_assets/assets/openclaw/$platform"
index_file="$build_assets/assets/openclaw/asset_index.json"

if [ ! -d "$source_dir" ]; then
  echo "Missing source OpenClaw assets: $source_dir" >&2
  exit 1
fi
if [ ! -d "$build_assets" ]; then
  echo "Missing Flutter build assets dir: $build_assets" >&2
  exit 1
fi

mkdir -p "$build_assets/assets/openclaw"
rm -rf "$target_dir"
cp -R "$source_dir/." "$target_dir"

python3 - "$build_assets" "$index_file" <<'PY_INDEX'
import json
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
index = pathlib.Path(sys.argv[2])
openclaw = root / 'assets' / 'openclaw'
items = sorted(path.relative_to(root).as_posix() for path in openclaw.rglob('*') if path.is_file())
manifest = root / 'AssetManifest.json'
existing = {}
if manifest.exists():
    try:
        existing = json.loads(manifest.read_text(encoding='utf-8'))
    except Exception:
        existing = {}
for item in items:
    existing[item] = [item]
manifest.write_text(json.dumps(existing, ensure_ascii=False, indent=2), encoding='utf-8')
index.write_text(json.dumps({'assets': items}, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Wrote {index} with {len(items)} assets')
PY_INDEX

if [[ "$platform" == windows-* ]] && [ ! -f "$target_dir/node/node.exe" ]; then
  echo "Synced Windows OpenClaw assets are missing node.exe" >&2
  exit 1
fi
if [ ! -f "$target_dir/openclaw/bin/openclaw.js" ]; then
  echo "Synced OpenClaw assets are missing openclaw/bin/openclaw.js" >&2
  exit 1
fi

file_count="$(find "$target_dir" -type f | wc -l | tr -d ' ')"
bytes="$(du -sk "$target_dir" | awk '{print $1}')"
echo "Synced OpenClaw $platform assets into $build_assets ($file_count files, ${bytes} KiB)."
