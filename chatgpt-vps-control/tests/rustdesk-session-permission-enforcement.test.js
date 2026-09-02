import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const source = (path) => readFileSync(resolve(root, path), "utf8");

test("session grant defaults are returned to desktop and mobile clients", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  assert.match(worker, /"permissions": \{"display": true, "input": true, "clipboard": false, "fileTransfer": false, "audio": false\}/);
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
