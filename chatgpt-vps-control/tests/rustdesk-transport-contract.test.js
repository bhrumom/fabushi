import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const source = (relativePath) => readFileSync(resolve(repositoryRoot, relativePath), "utf8");

test("transport negotiation is durable and provider-neutral", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0017_remote_computer_transport_contract.sql");
  assert.match(migration, /route_policy TEXT NOT NULL DEFAULT 'direct-first'/);
  assert.match(migration, /selected_route TEXT/);
  assert.match(migration, /selected_route IN \('direct', 'relay'\)/);
  assert.match(migration, /relay_region TEXT/);
  assert.match(migration, /remote_computer_sessions_transport_idx/);
  assert.doesNotMatch(migration, /hbbs_password|hbbr_password|device_secret TEXT|client_token TEXT|mobile_token TEXT/);
});

test("relay-only policy cannot downgrade to direct", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0017_remote_computer_transport_contract.sql");
  assert.match(migration, /remote_computer_session_route_policy_guard/);
  assert.match(migration, /NEW\.selected_route = 'direct'/);
  assert.match(migration, /OLD\.route_policy = 'relay-only'/);
  assert.match(migration, /relay-only session cannot select direct route/);
});

test("closed sessions cannot be assigned a new route", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0017_remote_computer_transport_contract.sql");
  const workerLib = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/lib.rs");
  assert.match(migration, /remote_computer_session_route_requires_live_session/);
  assert.match(migration, /OLD\.state = 'closed'/);
  assert.match(workerLib, /REMOTE_COMPUTER_TRANSPORT_CONTRACT_SCHEMA_V17/);
  assert.match(workerLib, /0017_remote_computer_transport_contract\.sql/);
});
