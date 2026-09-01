import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

function source(relativePath) {
  return readFileSync(resolve(repositoryRoot, relativePath), "utf8");
}

test("remote sessions persist the registered device provider", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0016_remote_computer_session_provider.sql");
  const inventory = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0015_remote_computer_inventory.sql");

  assert.match(migration, /ADD COLUMN provider TEXT NOT NULL DEFAULT 'fabushi-webrtc'/);
  assert.match(migration, /CHECK \(provider IN \('fabushi-webrtc', 'rustdesk-sidecar'\)\)/);
  assert.match(migration, /FROM remote_computers AS computer/);
  assert.match(migration, /computer\.device_id = NEW\.device_id/);
  assert.match(migration, /computer\.user_id = NEW\.user_id/);
  assert.match(migration, /remote session provider is immutable/);
  assert.match(migration, /remote_computer_sessions_provider_idx/);
  assert.match(inventory, /rustdesk-sidecar/);
});

test("provider binding remains control-plane metadata only", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0016_remote_computer_session_provider.sql");
  const workerLib = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/lib.rs");

  assert.match(workerLib, /REMOTE_COMPUTER_SESSION_PROVIDER_SCHEMA_V16/);
  assert.match(workerLib, /0016_remote_computer_session_provider\.sql/);
  assert.doesNotMatch(migration, /device_secret TEXT|client_token TEXT|mobile_token TEXT|screenshot_data|input_payload|clipboard_payload|file_payload|audio_payload/);
});

test("RDF-002 does not claim the RustDesk transport exists yet", () => {
  const readme = source("projects/rustdesk-fabushi-fusion/README.md");
  const wbs = source("projects/rustdesk-fabushi-fusion/management/01-WBS原子任务.md");

  assert.match(readme, /Current stage: M2 provider\/session abstraction/);
  assert.match(readme, /RustDesk sidecar transport is not implemented yet/);
  assert.match(wbs, /RDF-002 \| Provider\/session abstraction/);
  assert.match(wbs, /in-progress/);
});
