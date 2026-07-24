#!/usr/bin/env bash
set -euo pipefail

catalog_url="https://fabushi.ombhrum.com/.well-known/mahayana/marketplace.json"
plugin_id=""
platform=""
install_root=""

usage() {
  cat <<'EOF'
Usage: install-official-plugin.sh --plugin <id> [options]

Options:
  --catalog <url>       Marketplace catalog URL.
  --platform <target>   linux-x64, macos-x64, macos-arm64, or windows-x64.
  --install-root <dir>  Destination root. Defaults to $CODEX_HOME/plugins/fabushi-official.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plugin) plugin_id="${2:-}"; shift 2 ;;
    --catalog) catalog_url="${2:-}"; shift 2 ;;
    --platform) platform="${2:-}"; shift 2 ;;
    --install-root) install_root="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ "$plugin_id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "--plugin must be a valid marketplace plugin id" >&2
  exit 2
fi

if [ -z "$platform" ]; then
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  case "$os:$arch" in
    linux:x86_64|linux:amd64) platform="linux-x64" ;;
    darwin:x86_64|darwin:amd64) platform="macos-x64" ;;
    darwin:arm64|darwin:aarch64) platform="macos-arm64" ;;
    mingw*:x86_64|msys*:x86_64|cygwin*:x86_64) platform="windows-x64" ;;
    *) echo "unsupported platform: $os/$arch" >&2; exit 2 ;;
  esac
fi

case "$platform" in
  linux-x64|macos-x64|macos-arm64|windows-x64) ;;
  *) echo "unsupported target: $platform" >&2; exit 2 ;;
esac

for command in curl python3; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required" >&2; exit 2; }
done

if [ -z "$install_root" ]; then
  home="${CODEX_HOME:-${HOME:-}}"
  [ -n "$home" ] || { echo "HOME or CODEX_HOME is required" >&2; exit 2; }
  if [ -n "${CODEX_HOME:-}" ]; then
    install_root="$CODEX_HOME/plugins/fabushi-official"
  else
    install_root="$home/.codex/plugins/fabushi-official"
  fi
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
catalog="$work/marketplace.json"
curl --fail --location --silent --show-error "$catalog_url" --output "$catalog"

mapfile -t resolved < <(python3 - "$catalog" "$plugin_id" "$platform" <<'PY'
import json, sys
catalog_path, plugin_id, platform = sys.argv[1:]
with open(catalog_path, encoding="utf-8") as handle:
    catalog = json.load(handle)
plugins = {item["id"]: item for item in catalog.get("plugins", [])}
if plugin_id not in plugins:
    raise SystemExit(f"plugin not found in catalog: {plugin_id}")
artifact = catalog.get("artifacts", {}).get(platform)
if not artifact:
    raise SystemExit(f"platform not found in catalog: {platform}")
version = plugins[plugin_id]["version"]
print(artifact["urlTemplate"].replace("{plugin}", plugin_id).replace("{version}", version))
print(artifact["sha256UrlTemplate"].replace("{plugin}", plugin_id).replace("{version}", version))
print(version)
print(artifact["archiveFormat"])
PY
)
artifact_url="${resolved[0]}"
checksum_url="${resolved[1]}"
version="${resolved[2]}"
archive_format="${resolved[3]}"
archive="$work/$(basename "${artifact_url%%\?*}")"
checksum_file="$work/$(basename "${checksum_url%%\?*}")"

curl --fail --location --silent --show-error "$artifact_url" --output "$archive"
curl --fail --location --silent --show-error "$checksum_url" --output "$checksum_file"
expected="$(awk '{print $1; exit}' "$checksum_file")"
actual="$(python3 - "$archive" <<'PY'
import hashlib, sys
value = hashlib.sha256()
with open(sys.argv[1], "rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        value.update(chunk)
print(value.hexdigest())
PY
)"
[ "$expected" = "$actual" ] || { echo "SHA-256 mismatch for $archive" >&2; exit 1; }

extract="$work/extract"
mkdir -p "$extract"
case "$archive_format" in
  tar.gz) tar -xzf "$archive" -C "$extract" ;;
  zip)
    command -v unzip >/dev/null 2>&1 || { echo "unzip is required for Windows archives" >&2; exit 2; }
    unzip -q "$archive" -d "$extract"
    ;;
  *) echo "unsupported archive format: $archive_format" >&2; exit 2 ;;
esac
source="$extract/$plugin_id"
[ -d "$source" ] || { echo "archive does not contain $plugin_id" >&2; exit 1; }
python3 - "$source" "$plugin_id" <<'PY'
import json, pathlib, sys
root, plugin_id = pathlib.Path(sys.argv[1]), sys.argv[2]
with (root / ".codex-plugin/plugin.json").open(encoding="utf-8") as handle:
    manifest = json.load(handle)
assert manifest["name"] == plugin_id
assert (root / ".mahayana/plugin.json").is_file()
assert (root / ".mcp.json").is_file()
assert (root / "runtime/wasm/fabushi_official_miniapps_bg.wasm").is_file()
PY

mkdir -p "$install_root"
destination="$install_root/$plugin_id"
staging="$install_root/.${plugin_id}.installing.$$"
rm -rf "$staging"
cp -R "$source" "$staging"
rm -rf "$destination"
mv "$staging" "$destination"

cli="$destination/runtime/cli/fabushi-plugin-cli"
if [ "$platform" = "windows-x64" ]; then
  cli="$cli.exe"
else
  chmod 0755 "$cli"
fi
[ -f "$cli" ] || { echo "installed plugin CLI missing: $cli" >&2; exit 1; }
"$cli" --help >/dev/null
printf 'Installed %s %s for %s at %s\n' "$plugin_id" "$version" "$platform" "$destination"
