import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const source = (path) => readFileSync(resolve(root, path), "utf8");

test("remote sessions receive least-privilege durable grants", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0019_remote_computer_audit_grants.sql");
  assert.match(migration, /CREATE TABLE IF NOT EXISTS remote_computer_session_grants/);
  assert.match(migration, /allow_display INTEGER NOT NULL DEFAULT 1/);
  assert.match(migration, /allow_input INTEGER NOT NULL DEFAULT 1/);
  assert.match(migration, /allow_clipboard INTEGER NOT NULL DEFAULT 0/);
  assert.match(migration, /allow_file_transfer INTEGER NOT NULL DEFAULT 0/);
  assert.match(migration, /allow_audio INTEGER NOT NULL DEFAULT 0/);
  assert.match(migration, /remote_computer_session_default_grant/);
});

test("session grants are revocable and cannot be escalated in place", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0019_remote_computer_audit_grants.sql");
  assert.match(migration, /remote_computer_session_close_revoke_grant/);
  assert.match(migration, /SET revoked_at=/);
  assert.match(migration, /remote_computer_session_grant_no_escalation/);
  assert.match(migration, /NEW\.allow_clipboard>OLD\.allow_clipboard/);
  assert.match(migration, /remote session grants cannot be escalated in place/);
});

test("remote lifecycle and route decisions are auditable without payload persistence", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0019_remote_computer_audit_grants.sql");
  const workerLib = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/lib.rs");
  assert.match(migration, /CREATE TABLE IF NOT EXISTS remote_computer_audit_events/);
  assert.match(migration, /'session-created'/);
  assert.match(migration, /'session-activated'/);
  assert.match(migration, /'session-closed'/);
  assert.match(migration, /'route-selected'/);
  assert.match(migration, /'grant-revoked'/);
  assert.doesNotMatch(migration, /screenshot_data|input_payload|clipboard_payload|file_payload|audio_payload/);
  assert.match(workerLib, /REMOTE_COMPUTER_AUDIT_GRANTS_SCHEMA_V19/);
  assert.match(workerLib, /0019_remote_computer_audit_grants\.sql/);
});
