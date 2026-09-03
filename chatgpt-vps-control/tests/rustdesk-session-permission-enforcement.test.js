import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const source = (path) => readFileSync(resolve(root, path), "utf8");

test("session grant defaults remain least privilege while responses use authoritative persisted grants", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  assert.match(worker, /fn default_remote_control_permissions/);
  assert.match(worker, /display: true/);
  assert.match(worker, /input: true/);
  assert.match(worker, /clipboard: false/);
  assert.match(worker, /file_transfer: false/);
  assert.match(worker, /audio: false/);
  assert.match(worker, /JOIN remote_computer_session_grants g/);
  assert.match(worker, /"clipboard": row\.allow_clipboard != 0/);
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  assert.match(api, /normalizeRemoteControlPermissions/);
  assert.match(api, /permissions: normalizeRemoteControlPermissions\(raw\.permissions\)!/);
});

test("pending consent cannot negotiate transport or signaling", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  assert.match(worker, /session\.state != "active" \|\| session\.expires_at <= now/);
  assert.match(worker, /remote_computer_session_activate/);
  assert.match(worker, /state = 'pending'/);
});

test("desktop transport enforces display and input grants before host actions", () => {
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  assert.match(desktop, /!entry\.session\.permissions\.display/);
  assert.match(desktop, /Remote session does not grant display permission/);
  assert.match(desktop, /!entry\.session\.permissions\.input/);
  assert.match(desktop, /Remote session does not grant input permission/);
  assert.match(desktop, /normalizeRemotePermissions\(session\.permissions\)/);
});

test("session permission contract remains least privilege for unsupported channels", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0019_remote_computer_audit_grants.sql");
  assert.match(migration, /allow_clipboard INTEGER NOT NULL DEFAULT 0/);
  assert.match(migration, /allow_file_transfer INTEGER NOT NULL DEFAULT 0/);
  assert.match(migration, /allow_audio INTEGER NOT NULL DEFAULT 0/);
});

test("requested provider grants are persisted before activation and cannot be widened in place", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0020_remote_computer_requested_grants.sql");
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  assert.match(worker, /permissions: RemoteComputerPermissionsRequest/);
  assert.match(worker, /input\.permissions\.clipboard as i64/);
  assert.match(worker, /JOIN remote_computer_session_grants g/);
  assert.match(worker, /row\.allow_file_transfer != 0/);
  assert.match(migration, /NEW\.allow_clipboard/);
  assert.match(migration, /NEW\.allow_file_transfer/);
  assert.match(migration, /NEW\.allow_audio/);
  assert.match(api, /JSON\.stringify\(\{ clientId, clientToken, permissions \}\)/);
});


test("native RustDesk provider is reachable only after explicit active-session bootstrap", () => {
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  const mobile = source("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts");
  const shell = source("desktop/src/messaging-shell-v2.tsx");
  const main = source("desktop/electron/main.cjs");
  assert.match(desktop, /entry\.activated/);
  assert.match(desktop, /createRustDeskHostSessionCredential/);
  assert.match(desktop, /type: "rustdesk\.bootstrap"/);
  assert.match(desktop, /revokeRustDeskHostSessionCredential/);
  assert.match(mobile, /validateNativeRustDeskBootstrap/);
  assert.match(mobile, /nativeRustDesk\.connect/);
  assert.match(shell, /provider: 'rustdesk-sidecar'/);
  assert.match(main, /rotateTemporaryPassword/);
  assert.match(main, /rustDeskIssuedHostSessions/);
});

test("RustDesk temporary credentials never enter cloud signaling or audit persistence", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  const audit = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0019_remote_computer_audit_grants.sql");
  assert.doesNotMatch(worker, /temporaryPassword|rustdeskPassword|providerPassword/);
  assert.doesNotMatch(audit, /temporary_password|rustdesk_password|provider_password/);
});


test("native RustDesk credentials require an Electron main-process user-presence confirmation", () => {
  const main = source("desktop/electron/main.cjs");
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  assert.match(main, /dialog\.showMessageBox/);
  assert.match(main, /confirmation\.response !== 1/);
  assert.match(main, /grant\.display !== true/);
  assert.match(main, /RustDesk native session was denied by local user presence/);
  assert.match(desktop, /clientLabel: entry\.session\.clientLabel/);
  assert.match(desktop, /grant: entry\.session\.permissions/);
});

test("RustDesk host startup invalidates credentials that could survive a crash", () => {
  const main = source("desktop/electron/main.cjs");
  assert.match(main, /rustDeskHostDaemon\.start\(\)/);
  assert.match(main, /await rotateTemporaryPassword\(\{ app \}\)/);
  assert.match(main, /rustdesk-host\.startup-credential-invalidated/);
});
