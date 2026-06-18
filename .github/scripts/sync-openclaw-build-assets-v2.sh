#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
build_assets="${2:-}"

if [ -z "$platform" ] || [ -z "$build_assets" ]; then
  echo "usage: $0 <platform> <build-flutter-assets-dir>" >&2
  exit 2
fi

source_dir="assets/openclaw/$platform"
source_manifest="assets/openclaw/bundle_manifest.json"
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

mkdir -p "$openclaw_root"
rm -rf "$target_dir"
mkdir -p "$target_dir"
cp -R "$source_dir/." "$target_dir/"
find "$target_dir/openclaw" -type f \( \
  -name '*.d.ts' -o \
  -name '*.d.mts' -o \
  -name '*.map' -o \
  -name '*.tsbuildinfo' \
\) -delete

python3 - "$build_assets" "$index_file" "$bundle_manifest" "$source_manifest" <<'PY_INDEX'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
index = pathlib.Path(sys.argv[2])
bundle_manifest = pathlib.Path(sys.argv[3])
source_manifest = pathlib.Path(sys.argv[4])
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

def read_openclaw_bin(platform_name: str) -> str:
    package_json = openclaw / platform_name / "openclaw" / "package.json"
    if not package_json.exists():
        return "openclaw/openclaw.mjs"
    try:
        data = json.loads(package_json.read_text(encoding="utf-8"))
    except Exception:
        return "openclaw/openclaw.mjs"
    bin_field = data.get("bin")
    if isinstance(bin_field, str):
        return f"openclaw/{bin_field}"
    if isinstance(bin_field, dict):
        entry = bin_field.get("openclaw") or next(iter(bin_field.values()), None)
        if entry:
            return f"openclaw/{entry}"
    return "openclaw/openclaw.mjs"

source = {}
if source_manifest.exists():
    try:
        source = json.loads(source_manifest.read_text(encoding="utf-8"))
    except Exception:
        source = {}

platform_names = sorted(path.name for path in openclaw.iterdir() if path.is_dir())
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

output = {
    "schema": 1,
    "version": source.get("version") or "openclaw-embedded-2026.06.2",
    "defaultPort": source.get("defaultPort", 18789),
    "defaultModel": source.get("defaultModel", "openclaw/default"),
    "defaultModelOverride": source.get("defaultModelOverride", ""),
    "gatewayArgs": source.get("gatewayArgs") or ["gateway", "--port", "{port}", "--force"],
    "assets": items,
    "platforms": {},
}
if output["gatewayArgs"] == ["gateway", "--port", "{port}"]:
    output["gatewayArgs"] = ["gateway", "--port", "{port}", "--force"]

for platform_name in platform_names:
    output["platforms"][platform_name] = {
        "nodeExecutable": "node/node.exe" if platform_name.startswith("windows-") else "node/bin/node",
        "cliEntrypoint": read_openclaw_bin(platform_name),
    }

bundle_manifest.write_text(
    json.dumps(output, ensure_ascii=False, indent=2) + "\n",
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
cli_entrypoint="$(python3 - "$bundle_manifest" "$platform" <<'PY_CLI'
import json
import sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
platform = manifest.get("platforms", {}).get(sys.argv[2], {})
print(platform.get("cliEntrypoint", "openclaw/openclaw.mjs"))
PY_CLI
)"
if [ ! -f "$target_dir/$cli_entrypoint" ]; then
  echo "Synced OpenClaw assets are missing CLI entrypoint: $target_dir/$cli_entrypoint" >&2
  find "$target_dir/openclaw" -maxdepth 5 -type f | sort | head -200 >&2 || true
  exit 1
fi

file_count="$(find "$target_dir" -type f | wc -l | tr -d ' ')"
bytes="$(du -sk "$target_dir" | awk '{print $1}')"
echo "Synced OpenClaw $platform assets into $build_assets ($file_count files, ${bytes} KiB)."
