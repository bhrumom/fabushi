#!/usr/bin/env sh
# Install Mahayana CLI from a verified GitHub Release.
#
# Public entrypoint:
#   curl -fsSL https://raw.githubusercontent.com/bhrumom/fabushi/main/scripts/install-mahayana.sh | sh

set -eu

repository="${MAHAYANA_REPOSITORY:-bhrumom/fabushi}"
api_base_url="${MAHAYANA_API_BASE_URL:-https://api.github.com}"
install_dir="${MAHAYANA_INSTALL_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
version="${MAHAYANA_VERSION:-latest}"

die() {
  printf '%s\n' "mahayana installer: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install-mahayana.sh [--version <tag>] [--install-dir <dir>]

Environment overrides:
  MAHAYANA_VERSION             Release tag (default: newest release with a Mahayana archive)
  MAHAYANA_INSTALL_DIR         Destination directory (default: ~/.local/bin)
  MAHAYANA_CODEX_BIN           Development-only override for an embedded Codex binary
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || die "--version requires a release tag"
      version="$2"
      shift 2
      ;;
    --install-dir)
      [ "$#" -ge 2 ] || die "--install-dir requires a directory"
      install_dir="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ "$(uname -s)" = "Linux" ] || die "this installer currently supports Linux only"

case "$(uname -m)" in
  x86_64|amd64) target="x86_64-unknown-linux-musl" ;;
  aarch64|arm64) target="aarch64-unknown-linux-musl" ;;
  *) die "unsupported Linux architecture: $(uname -m)" ;;
esac

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"

fetch() {
  curl --fail --silent --show-error --location "$1"
}

find_asset_url() {
  metadata="$1"
  asset_name="$2"
  printf '%s\n' "$metadata" | awk -v suffix="/$asset_name\"" '
    index($0, "\"browser_download_url\":") && index($0, suffix) {
      sub(/^[^\"]*\"browser_download_url\":[[:space:]]*\"/, "")
      sub(/\".*$/, "")
      print
      exit
    }
  '
}

archive_name="mahayana-${target}.tar.gz"
checksum_name="${archive_name}.sha256"
archive_url="${MAHAYANA_RELEASE_URL:-}"
checksum_url="${MAHAYANA_CHECKSUM_URL:-}"

if [ -z "$archive_url" ] || [ -z "$checksum_url" ]; then
  api_base_url="${api_base_url%/}"
  if [ "$version" = "latest" ]; then
    metadata="$(fetch "${api_base_url}/repos/${repository}/releases?per_page=100")" || die "could not list GitHub releases"
  else
    metadata="$(fetch "${api_base_url}/repos/${repository}/releases/tags/${version}")" || die "could not find release ${version}"
  fi
  archive_url="$(find_asset_url "$metadata" "$archive_name")"
  checksum_url="$(find_asset_url "$metadata" "$checksum_name")"
fi

[ -n "$archive_url" ] || die "no ${archive_name} asset was found; publish a mahayana-v* release first"
[ -n "$checksum_url" ] || die "no checksum asset was found for ${archive_name}"

temporary_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT HUP INT TERM

archive_path="${temporary_dir}/${archive_name}"
checksum_path="${temporary_dir}/${checksum_name}"
fetch "$archive_url" > "$archive_path" || die "could not download ${archive_name}"
fetch "$checksum_url" > "$checksum_path" || die "could not download ${checksum_name}"

expected_checksum="$(awk 'NR == 1 { print $1 }' "$checksum_path")"
[ "${#expected_checksum}" -eq 64 ] || die "release checksum is invalid"
actual_checksum="$(sha256sum "$archive_path" | awk '{ print $1 }')"
[ "$actual_checksum" = "$expected_checksum" ] || die "SHA-256 verification failed"

mkdir -p "${temporary_dir}/payload"
tar -xzf "$archive_path" -C "${temporary_dir}/payload" || die "could not unpack ${archive_name}"
binary_path="${temporary_dir}/payload/bin/mahayana"
bundled_codex_path="${temporary_dir}/payload/lib/mahayana/codex"
[ -f "$binary_path" ] || die "release archive does not contain bin/mahayana"
[ -f "$bundled_codex_path" ] || die "release archive does not contain lib/mahayana/codex"

mkdir -p "$install_dir"
install -m 0755 "$binary_path" "${install_dir}/mahayana"
install_prefix="$(dirname "$install_dir")"
bundled_codex_destination="${install_prefix}/lib/mahayana/codex"
mkdir -p "$(dirname "$bundled_codex_destination")"
install -m 0755 "$bundled_codex_path" "$bundled_codex_destination"
printf '%s\n' "Installed Mahayana CLI to ${install_dir}/mahayana with bundled Codex at ${bundled_codex_destination}"

case ":$PATH:" in
  *":${install_dir}:"*) ;;
  *) printf '%s\n' "Add ${install_dir} to PATH, then start a new shell." ;;
esac

printf '%s\n' 'Next: run `mahayana login`, then `mahayana status`.'
