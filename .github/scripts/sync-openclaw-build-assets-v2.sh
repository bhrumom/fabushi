#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
build_assets="${2:-}"

if [ -z "$platform" ] || [ -z "$build_assets" ]; then
  echo "usage: $0 <platform> <build-flutter-assets-dir>" >&2
  exit 2
fi

source_dir="assets/openclaw/$platform"
openclaw_root="$build_assets/assets/openclaw"
target_dir="$openclaw_root/$platform"
index_file="$openclaw_root/asset_index.json"
bundle_manifest="$openclaw_root/bundle_manifest.json"

if [ ! -d "$source_dir" ]; then
  echo "Missing source OpenClaw assets: $source_dir" >&2
  exit 1
fi
if [ ! -d "$build_assets" ]; then
  echo "Missing Flutter build assets dir: $build_assets" >&2
  exit 1
fi

mkdir -p "$target_dir"
rm -rf "$target_dir"
mkdir -p "$target_dir"
cp -R "$source_dir/." "$target_dir/"

python3 - "$build_assets" "$index_file" "$bundle_manifest" <<'PY_INDEX'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
index = pathlib.Path(sys.argv[2])
bundle_manifest = pathlib.Path(sys.argv[3])
openclaw = root / "assets" / "openclaw"

items = sorted(
    path.relative_to(root).as_posix()
    for path in openclaw.rglob("*")
    if path.is_file()
)

manifest = root / "AssetManifest.json"
existing = {}
if manifest.exists():
    try:
        parsed = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception:
        parsed = {}
    if isinstance(parsed, dict):
        existing = parsed
    elif isinstance(parsed, list):
        existing = {str(item): [str(item)] for item in parsed}

for item in items:
    existing[item] = [item]

manifest.write_text(
    json.dumps(existing, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
index.write_text(
    json.dumps({"assets": items}, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
bundle_manifest.write_text(
    json.dumps(
        {
            "assets": items,
            "platforms": sorted(
                path.name
                for path in openclaw.iterdir()
                if path.is_dir()
            ),
        },
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
print(f"Wrote {index} and {bundle_manifest} with {len(items)} assets")
PY_INDEX

if [[ "$platform" == windows-* ]] && [ ! -f "$target_dir/node/node.exe" ]; then
  echo "Synced Windows OpenClaw assets are missing node.exe" >&2
  find "$target_dir" -maxdepth 4 -type f | sort | head -200 >&2 || true
  exit 1
fi
if [[ "$platform" != windows-* ]] && [ ! -x "$target_dir/node/bin/node" ]; then
  echo "Synced OpenClaw assets are missing executable node binary: $target_dir/node/bin/node" >&2
  find "$target_dir/node" -maxdepth 4 -type f | sort | head -200 >&2 || true
  exit 1
fi
if [ ! -f "$target_dir/openclaw/bin/openclaw.js" ]; then
  echo "Synced OpenClaw assets are missing openclaw/bin/openclaw.js" >&2
  find "$target_dir/openclaw" -maxdepth 5 -type f | sort | head -200 >&2 || true
  exit 1
fi

file_count="$(find "$target_dir" -type f | wc -l | tr -d ' ')"
bytes="$(du -sk "$target_dir" | awk '{print $1}')"
echo "Synced OpenClaw $platform assets into $build_assets ($file_count files, ${bytes} KiB)."
