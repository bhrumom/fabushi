import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const source = (path) => readFileSync(resolve(root, path), "utf8");

test("RustDesk sidecar is pinned, AGPL separated, and preserves Fabushi identity authority", () => {
  const lock = source("integrations/rustdesk-sidecar/UPSTREAM.lock");
  const readme = source("integrations/rustdesk-sidecar/README.md");
  assert.match(lock, /^repository=https:\/\/github\.com\/rustdesk\/rustdesk\.git$/m);
  assert.match(lock, /^commit=f28ac38ccfa662fd06639a062e0d06249860b142$/m);
  assert.match(lock, /^license=AGPL-3\.0-only$/m);
  assert.match(readme, /Fabushi remains authoritative for account identity/);
  assert.match(readme, /MUST NOT be passed into the RustDesk process/);
  assert.match(readme, /separately built and distributable AGPL-3\.0-only derivative/);
});

test("sidecar protocol is inherited stdio only and enforces immutable grants", () => {
  const sidecar = source("integrations/rustdesk-sidecar/overlay/src/bin/fabushi_sidecar.rs");
  assert.match(sidecar, /const PROTOCOL: &str = "fabushi\.rustdesk-sidecar\.v1"/);
  assert.match(sidecar, /io::stdin\(\)/);
  assert.match(sidecar, /io::stdout\(\)/);
  assert.doesNotMatch(sidecar, /TcpListener|UdpSocket|axum|warp::|hyper::Server|actix_web/);
  assert.match(sidecar, /if !session\.grant\.input \{ return Err\("input-not-granted"\); \}/);
  assert.match(sidecar, /server_keyboard_enabled: Arc::new\(RwLock::new\(grant\.input\)\)/);
  assert.match(sidecar, /server_file_transfer_enabled: Arc::new\(RwLock::new\(grant\.file_transfer\)\)/);
  assert.match(sidecar, /server_clipboard_enabled: Arc::new\(RwLock::new\(grant\.clipboard\)\)/);
  assert.match(sidecar, /if !grant\.display \{ return Err\("display-grant-required"\.into\(\)\); \}/);
  assert.doesNotMatch(sidecar, /accountToken|bearerToken|deviceSecret|cookie/i);
});

test("sidecar source preparation refuses unpinned repositories and preserves corresponding-source metadata", () => {
  const prepare = source("integrations/rustdesk-sidecar/prepare-source.sh");
  assert.match(prepare, /unexpected RustDesk repository/);
  assert.match(prepare, /git -C "\$DEST" checkout --detach "\$COMMIT"/);
  assert.match(prepare, /git -C "\$DEST" rev-parse HEAD/);
  assert.match(prepare, /FABUSHI-SIDECAR-SOURCE\.txt/);
  assert.match(prepare, /pub mod client;/);
  assert.match(prepare, /pub mod ui_session_interface;/);
});
