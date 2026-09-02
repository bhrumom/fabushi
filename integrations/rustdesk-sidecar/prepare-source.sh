#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$ROOT/integrations/rustdesk-sidecar/UPSTREAM.lock"
REPOSITORY="$(sed -n 's/^repository=//p' "$LOCK")"
COMMIT="$(sed -n 's/^commit=//p' "$LOCK")"
DEST="${1:-$ROOT/.cache/rustdesk-sidecar-src}"

case "$COMMIT" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "invalid RustDesk commit pin" >&2; exit 2 ;;
esac
[ "$REPOSITORY" = "https://github.com/rustdesk/rustdesk.git" ] || { echo "unexpected RustDesk repository" >&2; exit 2; }

rm -rf "$DEST"
git clone --filter=blob:none --no-checkout "$REPOSITORY" "$DEST"
git -C "$DEST" checkout --detach "$COMMIT"
[ "$(git -C "$DEST" rev-parse HEAD)" = "$COMMIT" ] || { echo "RustDesk checkout does not match pin" >&2; exit 3; }

git -C "$DEST" submodule update --init --recursive

python3 - "$DEST" "$ROOT" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
root = Path(sys.argv[2])
lib = source / 'src/lib.rs'
text = lib.read_text()
for old, new in [('mod client;', 'pub mod client;'), ('mod ui_session_interface;', 'pub mod ui_session_interface;')]:
    if old not in text and new not in text:
        raise SystemExit(f'missing expected RustDesk export marker: {old}')
    text = text.replace(old, new, 1)
lib.write_text(text)

overlay = root / 'integrations/rustdesk-sidecar/overlay/src/bin/fabushi_sidecar.rs'
target = source / 'src/bin/fabushi_sidecar.rs'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(overlay.read_text())

cargo = source / 'Cargo.toml'
manifest = cargo.read_text()
entry = '\n[[bin]]\nname = "fabushi-sidecar"\npath = "src/bin/fabushi_sidecar.rs"\n'
if 'name = "fabushi-sidecar"' not in manifest:
    manifest += entry
cargo.write_text(manifest)
PY

cat > "$DEST/FABUSHI-SIDECAR-SOURCE.txt" <<EOF
Fabushi RustDesk sidecar corresponding source
upstream=$REPOSITORY
commit=$COMMIT
overlay=integrations/rustdesk-sidecar/overlay/src/bin/fabushi_sidecar.rs
license=AGPL-3.0-only
EOF

echo "$DEST"
