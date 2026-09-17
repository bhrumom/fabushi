import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const source = (path) => readFileSync(resolve(root, path), "utf8");

test("server owns direct/relay selection behind authenticated session actors", () => {
  const remote = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs");
  assert.match(worker, /sessions\/:session_id\/transport/);
  assert.match(remote, /remote_computer_session_transport/);
  assert.match(remote, /remote_session_actor_allowed/);
  assert.match(remote, /route_policy == "relay-only"/);
  assert.match(remote, /direct_available/);
  assert.match(remote, /REMOTE_TURN_URL/);
  assert.match(remote, /RUSTDESK_RELAY_URL/);
  assert.match(remote, /selected_route = 'direct' AND \?1 = 'relay'/);
});

test("relay fallback is monotonic and audited without storing credentials", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0018_remote_computer_transport_audit.sql");
  assert.match(migration, /remote_computer_transport_no_relay_to_direct/);
  assert.match(migration, /remote_computer_transport_audit/);
  assert.match(migration, /previous_route/);
  assert.match(migration, /selected_route/);
  assert.doesNotMatch(migration, /device_secret|mobile_token|client_token|credential|password/);
});
