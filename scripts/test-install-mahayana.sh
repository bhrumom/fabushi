#!/usr/bin/env sh

set -eu

repository_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
temporary_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT HUP INT TERM

target="x86_64-unknown-linux-musl"
archive_name="mahayana-${target}.tar.gz"
payload_dir="${temporary_dir}/payload"
install_dir="${temporary_dir}/install/bin"
fake_bin_dir="${temporary_dir}/fake-bin"
api_dir="${temporary_dir}/api/repos/bhrumom/fabushi"
mkdir -p "$fake_bin_dir"
printf '%s\n' '#!/usr/bin/env sh' 'case "$1" in -s) printf "Linux\\n" ;; -m) printf "x86_64\\n" ;; *) exit 64 ;; esac' > "${fake_bin_dir}/uname"
chmod 0755 "${fake_bin_dir}/uname"
mkdir -p "${payload_dir}/bin"
mkdir -p "${payload_dir}/lib/mahayana"
printf '%s\n' '#!/usr/bin/env sh' 'printf "mahayana test binary\\n"' > "${payload_dir}/bin/mahayana"
printf '%s\n' '#!/usr/bin/env sh' 'printf "bundled codex test binary\\n"' > "${payload_dir}/lib/mahayana/codex"
chmod 0755 "${payload_dir}/bin/mahayana"
chmod 0755 "${payload_dir}/lib/mahayana/codex"
tar -C "$payload_dir" -czf "${temporary_dir}/${archive_name}" .
sha256sum "${temporary_dir}/${archive_name}" > "${temporary_dir}/${archive_name}.sha256"
mkdir -p "$api_dir"
printf '%s\n' \
  '[' \
  "  {\"browser_download_url\": \"file://${temporary_dir}/${archive_name}\"}," \
  "  {\"browser_download_url\": \"file://${temporary_dir}/${archive_name}.sha256\"}" \
  ']' > "${api_dir}/releases"

MAHAYANA_API_BASE_URL="file://${temporary_dir}/api" \
MAHAYANA_INSTALL_DIR="$install_dir" \
PATH="${fake_bin_dir}:/sbin:/usr/bin:/bin" \
sh "${repository_root}/scripts/install-mahayana.sh"

test -x "${install_dir}/mahayana"
test -x "${temporary_dir}/install/lib/mahayana/codex"
test "$("${install_dir}/mahayana")" = "mahayana test binary"
test "$("${temporary_dir}/install/lib/mahayana/codex")" = "bundled codex test binary"
printf '%s\n' 'Mahayana installer smoke test passed.'
