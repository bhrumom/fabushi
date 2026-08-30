import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

async function text(path) {
  return readFile(new URL(path, root), "utf8");
}

test("remote MCP systemd service is loopback-fronted and sandboxed", async () => {
  const [unit, env] = await Promise.all([
    text("systemd/fabushi-remote-mcp.service"),
    text("systemd/fabushi-remote-mcp.env.example"),
  ]);
  assert.match(unit, /^User=fabushi-mcp$/m);
  assert.match(unit, /^NoNewPrivileges=true$/m);
  assert.match(unit, /^ProtectSystem=strict$/m);
  assert.match(unit, /^ProtectHome=true$/m);
  assert.match(unit, /^CapabilityBoundingSet=$/m);
  assert.match(unit, /^StateDirectory=fabushi-remote-mcp$/m);
  assert.match(env, /^FABUSHI_REMOTE_MCP_HOST=127\.0\.0\.1$/m);
  assert.match(env, /^FABUSHI_REMOTE_MCP_PUBLIC_ORIGIN=https:\/\/fabushi-mcp\.ombhrum\.com$/m);
  assert.doesNotMatch(`${unit}\n${env}`, /DEVICE_GATEWAY_TOKEN|PASSWORD|PRIVATE_KEY/);
});

test("interactive Runner evidence allowlist excludes account sessions and secrets", async () => {
  const workflow = await readFile(new URL("../../.github/workflows/interactive-runner-mcp.yml", import.meta.url), "utf8");
  const upload = workflow.slice(workflow.indexOf("name: Upload interactive Runner evidence"));
  assert.match(upload, /device-calls\.jsonl/);
  assert.match(upload, /generated-regression\.json/);
  assert.doesNotMatch(upload, /account-session|session\.json|token-file|computer-policy\.json/);
});
