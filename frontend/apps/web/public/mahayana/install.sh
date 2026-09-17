#!/bin/sh
set -eu

repo="${MAHAYANA_CLI_REPOSITORY:-bhrumom/fabushi}"
channel="${MAHAYANA_CLI_CHANNEL:-}"
if [ -z "$channel" ]; then
  releases="$(curl -fsSL --retry 3 --connect-timeout 15 \
    -H 'Accept: application/vnd.github+json' \
    -H 'User-Agent: mahayana-cli-installer' \
    "https://api.github.com/repos/${repo}/releases?per_page=100")"
  channel="$(printf '%s' "$releases" \
    | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"mahayana-cli-main-[0-9a-f]{12}"' \
    | sed -E 's/.*"(mahayana-cli-main-[0-9a-f]{12})"/\1/' \
    | head -n 1)"
  [ -n "$channel" ] || { echo "No promoted Mahayana CLI protected-main release was found." >&2; exit 1; }
fi
base="https://github.com/${repo}/releases/download/${channel}"
os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux) platform="linux" ;;
  Darwin) platform="macos" ;;
  *) echo "Unsupported operating system: $os" >&2; exit 1 ;;
esac
case "$arch" in
  x86_64|amd64) machine="x86_64" ;;
  arm64|aarch64) machine="aarch64" ;;
  *) echo "Unsupported CPU architecture: $arch" >&2; exit 1 ;;
esac

asset="mahayana-${platform}-${machine}.tar.gz"
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t mahayana-cli)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

curl -fL --retry 3 --connect-timeout 15 "${base}/${asset}" -o "$tmp/$asset"
curl -fL --retry 3 --connect-timeout 15 "${base}/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt"
expected="$(awk -v asset="$asset" '$2 == asset || $2 == "*" asset {print $1; exit}' "$tmp/SHA256SUMS.txt")"
[ -n "$expected" ] || { echo "No checksum found for $asset" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/$asset" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"
else
  echo "sha256sum or shasum is required to verify Mahayana CLI." >&2
  exit 1
fi
[ "$actual" = "$expected" ] || { echo "Checksum verification failed for $asset" >&2; exit 1; }

tar -xzf "$tmp/$asset" -C "$tmp"
[ -f "$tmp/mahayana" ] || { echo "Release archive does not contain mahayana" >&2; exit 1; }
install_dir="${MAHAYANA_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$install_dir"
install -m 0755 "$tmp/mahayana" "$install_dir/mahayana"
"$install_dir/mahayana" device start >/dev/null 2>&1 || true

echo "Mahayana CLI installed: $install_dir/mahayana"
case ":${PATH:-}:" in
  *":$install_dir:"*) ;;
  *) echo "Add $install_dir to PATH, then run: mahayana login" ;;
esac
