import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { createFabushiRemoteMcpServer } from "../lib/fabushi-remote-mcp-server.js";
import {
  callRegisteredDevice,
  listRegisteredDevices,
  resetDeviceGatewayStateForTests,
} from "../lib/device-gateway.js";
import { resolveDeviceAgentConfig, startDeviceAgent } from "../lib/device-agent.js";

const fixture = resolve(dirname(fileURLToPath(import.meta.url)), "fixtures/stdio-device-mcp.mjs");

test("device agent registers a stdio MCP under the Fabushi account and proxies calls", async (t) => {
  resetDeviceGatewayStateForTests();
  const service = createFabushiRemoteMcpServer({
    host: "127.0.0.1",
    port: 0,
    statePath: "",
    auditPath: "",
    accountClient: {
      async resolveAccessToken(token) {
        if (token !== "r".repeat(32)) throw new Error("unauthorized");
        return { userId: "user:runner-account", label: "Runner Account" };
      },
    },
  });
  const address = await service.listen();
  const logs = [];
  const agent = startDeviceAgent({
    config: {
      gatewayUrl: `ws://127.0.0.1:${address.port}/agent`,
      gatewayToken: "r".repeat(32),
      local: { kind: "stdio", command: process.execPath, args: [fixture], cwd: process.cwd(), env: { PATH: process.env.PATH || "" } },
      deviceId: "gha-fixture-1",
      deviceName: "GitHub Actions Fixture",
      leaseSeconds: 90,
      metadata: { kind: "github-actions", runId: "9001" },
      ipFamily: 0,
    },
    log: (message) => logs.push(message),
    error: (message) => logs.push(message),
  });
  t.after(async () => {
    await agent.stop();
    await service.close();
    resetDeviceGatewayStateForTests();
  });
  const registered = await agent.waitUntilRegistered(10_000);
  assert.equal(registered.deviceId, "gha-fixture-1");
  const devices = listRegisteredDevices("user:runner-account");
  assert.equal(devices.length, 1);
  assert.deepEqual(devices[0].capabilities, ["computer_state", "secure_input_submit"]);
  assert.equal(devices[0].toolSchemaCount, 1);
  assert.equal(devices[0].metadata.runId, "9001");
  const result = await callRegisteredDevice("user:runner-account", "gha-fixture-1", "computer_state", { application: "Fabushi" }, 10);
  assert.equal(result.ok, true);
  assert.deepEqual(result.result.structuredContent, { activeApp: "Fabushi", requestedApp: "Fabushi" });
  assert.ok(logs.some((line) => line.includes("registered")));
});

test("device agent config uses a Fabushi account token file without forwarding it to the local MCP", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-agent-config-"));
  try {
    const tokenFile = join(root, "account-token");
    await writeFile(tokenFile, `${"t".repeat(48)}\n`, { mode: 0o600 });
    const config = resolveDeviceAgentConfig({
      DEVICE_GATEWAY_URL: "wss://mcp.example.test/agent",
      FABUSHI_ACCOUNT_TOKEN_FILE: tokenFile,
      DEVICE_LOCAL_MCP_ENTRY: fixture,
      FABUSHI_COMPUTER_POLICY_FILE: join(root, "policy.json"),
      GITHUB_ACTIONS: "true",
      GITHUB_REPOSITORY: "bhrumom/fabushi",
      GITHUB_RUN_ID: "123",
      GITHUB_RUN_ATTEMPT: "2",
      GITHUB_JOB: "interactive_runner",
      PATH: process.env.PATH || "",
    });
    assert.equal(config.gatewayToken, "t".repeat(48));
    assert.equal(config.deviceId, "gha-123-2-interactive_runner");
    assert.equal(config.metadata.kind, "github-actions");
    assert.equal(config.local.kind, "stdio");
    assert.equal(config.local.env.FABUSHI_ACCOUNT_TOKEN_FILE, undefined);
    assert.equal(config.local.env.FABUSHI_COMPUTER_POLICY_FILE, join(root, "policy.json"));
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("device agent rejects cleartext non-loopback gateways", () => {
  assert.throws(() => resolveDeviceAgentConfig({
    DEVICE_GATEWAY_URL: "ws://mcp.example.test/agent",
    FABUSHI_ACCOUNT_ACCESS_TOKEN: "x".repeat(48),
    DEVICE_LOCAL_MCP_ENTRY: fixture,
  }), /wss/);
});
