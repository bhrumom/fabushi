import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

function source(relativePath) {
  return readFileSync(resolve(repositoryRoot, relativePath), "utf8");
}

test("account-scoped device inventory is durable and secret-free", () => {
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0015_remote_computer_inventory.sql");
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");

  for (const field of ["provider", "platform", "app_version", "capabilities_json"]) {
    assert.match(migration, new RegExp(`ADD COLUMN ${field}\\b`));
  }
  assert.match(worker, /WHERE computer\.user_id = \?1 AND computer\.revoked_at IS NULL/);
  assert.match(worker, /session\.user_id = computer\.user_id/);
  assert.match(worker, /"activeSessionCount": row\.active_session_count/);
  assert.match(worker, /now\.saturating_sub\(row\.last_seen_at\) <= 45/);
  assert.doesNotMatch(migration, /device_secret TEXT|screenshot_data|input_payload/);
});

test("desktop registration forwards honest Fabushi capabilities end to end", () => {
  const contracts = source("frontend/apps/web/src/lib/mahayana-host/contracts.ts");
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  const protocol = source("third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs");
  const host = source("third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs");
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");

  for (const field of ["provider", "platform", "appVersion", "capabilities"]) {
    assert.ok(contracts.includes(field), `missing TypeScript field ${field}`);
    assert.ok(desktop.includes(field), `desktop does not send ${field}`);
    assert.ok(host.includes(`"${field}"`), `Feature Host does not forward ${field}`);
  }
  assert.match(protocol, /provider: Option<String>/);
  assert.match(protocol, /app_version: Option<String>/);
  assert.match(protocol, /capabilities: Vec<String>/);
  assert.match(worker, /"rustdesk-sidecar"/);

  const capabilityStart = desktop.indexOf("const FABUSHI_WEBRTC_CAPABILITIES");
  const capabilityEnd = desktop.indexOf("];", capabilityStart);
  assert.ok(capabilityStart >= 0 && capabilityEnd > capabilityStart);
  const actualCapabilities = desktop.slice(capabilityStart, capabilityEnd);
  for (const capability of ["remote-desktop", "input", "display", "session-management"]) {
    assert.ok(actualCapabilities.includes(`"${capability}"`));
  }
  assert.doesNotMatch(actualCapabilities, /clipboard|file-transfer|audio/);
});

test("device list exposes status, detail, search, and capability filters", () => {
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  const page = source("frontend/apps/web/src/app/remote-computer/page.tsx");

  for (const field of ["provider", "platform", "appVersion", "capabilities", "activeSessionCount"]) {
    assert.ok(api.includes(field), `API mapping is missing ${field}`);
    assert.ok(page.includes(field), `device list is missing ${field}`);
  }
  assert.match(page, /deviceQuery/);
  assert.match(page, /statusFilter/);
  assert.match(page, /capabilityFilter/);
  assert.match(page, /formatRelativeOnline/);
});

test("RustDesk remains an isolated AGPL compatibility boundary", () => {
  const adr = source("projects/rustdesk-fabushi-fusion/decisions/ADR-0001-provider-license-boundary.md");
  const mapping = source("projects/rustdesk-fabushi-fusion/docs/08-RustDesk能力映射.md");

  assert.match(adr, /AGPL-3\.0/);
  assert.match(adr, /rustdesk-sidecar/);
  assert.match(mapping, /rustdesk\/rustdesk@f28ac38ccfa662fd06639a062e0d06249860b142/);
  assert.match(mapping, /rustdesk\/hbb_common@b2b1ac453d1d694046f63be20d792d608dac1c93/);
});
