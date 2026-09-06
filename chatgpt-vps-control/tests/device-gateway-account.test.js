import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";
import WebSocket from "ws";
import {
  attachDeviceGateway,
  callRegisteredDevice,
  listRegisteredDevices,
  resetDeviceGatewayStateForTests,
} from "../lib/device-gateway.js";

function listen(server) {
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server.address().port)));
}

function opened(ws) {
  return new Promise((resolve, reject) => {
    ws.once("open", resolve);
    ws.once("error", reject);
  });
}

function nextJson(ws) {
  return new Promise((resolve, reject) => {
    ws.once("message", (raw) => {
      try { resolve(JSON.parse(raw.toString("utf8"))); } catch (error) { reject(error); }
    });
    ws.once("error", reject);
  });
}

async function closeServer(server, gateway) {
  await gateway.close();
  await new Promise((resolve) => server.close(resolve));
}

test("device gateway isolates equal device ids by Fabushi account and routes calls", async (t) => {
  resetDeviceGatewayStateForTests();
  const server = createServer((_req, res) => res.writeHead(404).end());
  const gateway = attachDeviceGateway(server, {
    resolveAccount: async (token) => ({
      "token-account-a": { userId: "account:a" },
      "token-account-b": { userId: "account:b" },
    })[token] ?? null,
    defaultLeaseSeconds: 60,
  });
  const port = await listen(server);
  const a = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer token-account-a" } });
  const b = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer token-account-b" } });
  t.after(async () => {
    a.terminate();
    b.terminate();
    await closeServer(server, gateway);
    resetDeviceGatewayStateForTests();
  });
  await Promise.all([opened(a), opened(b)]);
  const descriptor = {
    name: "computer_state",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    outputSchema: { type: "object" },
  };
  a.send(JSON.stringify({ type: "register", deviceId: "runner-1", name: "Runner A", platform: "linux", capabilities: ["computer_state"], tools: [descriptor], metadata: { kind: "github-actions", runId: "11" } }));
  b.send(JSON.stringify({ type: "register", deviceId: "runner-1", name: "Runner B", platform: "linux", capabilities: ["computer_state"], tools: [descriptor], metadata: { kind: "github-actions", runId: "22" } }));
  await Promise.all([nextJson(a), nextJson(b)]);
  assert.equal(listRegisteredDevices("account:a")[0].name, "Runner A");
  assert.equal(listRegisteredDevices("account:b")[0].name, "Runner B");
  assert.equal(listRegisteredDevices("account:a")[0].metadata.runId, "11");
  assert.equal(listRegisteredDevices("account:missing").length, 0);

  a.once("message", (raw) => {
    const call = JSON.parse(raw.toString("utf8"));
    if (call.type === "call") a.send(JSON.stringify({ type: "result", requestId: call.requestId, ok: true, result: { structuredContent: { app: "Fabushi" } } }));
  });
  const result = await callRegisteredDevice("account:a", "runner-1", "computer_state", {});
  assert.deepEqual(result.result.structuredContent, { app: "Fabushi" });
  await assert.rejects(() => callRegisteredDevice("account:b", "runner-1", "missing_tool", {}), /does not expose/);
});

test("device gateway rejects an unrecognized Fabushi account bearer", async (t) => {
  resetDeviceGatewayStateForTests();
  const server = createServer((_req, res) => res.writeHead(404).end());
  const gateway = attachDeviceGateway(server, { resolveAccount: async () => null });
  const port = await listen(server);
  const ws = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer bad-token" } });
  t.after(async () => {
    ws.terminate();
    await closeServer(server, gateway);
    resetDeviceGatewayStateForTests();
  });
  const status = await new Promise((resolve) => {
    ws.once("unexpected-response", (_request, response) => resolve(response.statusCode));
    ws.once("error", () => {});
  });
  assert.equal(status, 401);
});

test("device reconnect rejects calls that were bound to the previous socket generation", async (t) => {
  resetDeviceGatewayStateForTests();
  const server = createServer((_req, res) => res.writeHead(404).end());
  const gateway = attachDeviceGateway(server, {
    resolveAccount: async (token) => token === "token-account-a" ? { userId: "account:a" } : null,
    defaultLeaseSeconds: 60,
  });
  const port = await listen(server);
  const first = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer token-account-a" } });
  let replacement = null;
  t.after(async () => {
    first.terminate();
    replacement?.terminate();
    await closeServer(server, gateway);
    resetDeviceGatewayStateForTests();
  });
  await opened(first);
  const descriptor = { name: "computer_state", inputSchema: { type: "object" }, outputSchema: { type: "object" } };
  first.send(JSON.stringify({
    type: "register",
    deviceId: "runner-reconnect",
    name: "First generation",
    platform: "linux",
    capabilities: ["computer_state"],
    tools: [descriptor],
    secureInputPublicKey: { kty: "EC", crv: "P-256", x: "a".repeat(43), y: "b".repeat(43) },
  }));
  await nextJson(first);
  assert.equal(listRegisteredDevices("account:a")[0].secureInputPublicKey.crv, "P-256");

  const pendingRejection = assert.rejects(
    callRegisteredDevice("account:a", "runner-reconnect", "computer_state", {}, 30),
    /reconnected/,
  );
  const outbound = await nextJson(first);
  assert.equal(outbound.type, "call");

  replacement = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer token-account-a" } });
  await opened(replacement);
  replacement.send(JSON.stringify({
    type: "register",
    deviceId: "runner-reconnect",
    name: "Second generation",
    platform: "linux",
    capabilities: ["computer_state"],
    tools: [descriptor],
  }));
  await nextJson(replacement);
  await pendingRejection;
  assert.equal(listRegisteredDevices("account:a")[0].name, "Second generation");
});

test("device gateway keeps the registered socket alive when async audit rejects", async (t) => {
  resetDeviceGatewayStateForTests();
  const server = createServer((_req, res) => res.writeHead(404).end());
  const gateway = attachDeviceGateway(server, {
    resolveAccount: async (token) => token === "token-account-a" ? { userId: "account:a" } : null,
    audit: async () => { throw new Error("simulated ENOSPC"); },
    defaultLeaseSeconds: 60,
  });
  const port = await listen(server);
  const ws = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer token-account-a" } });
  t.after(async () => {
    ws.terminate();
    await closeServer(server, gateway);
    resetDeviceGatewayStateForTests();
  });
  await opened(ws);
  ws.send(JSON.stringify({
    type: "register",
    deviceId: "audit-rejection-device",
    name: "Audit rejection device",
    platform: "android",
    capabilities: ["fabushi.app.status"],
  }));
  const registered = await nextJson(ws);
  assert.equal(registered.type, "registered");
  await new Promise((resolve) => setTimeout(resolve, 25));
  assert.equal(ws.readyState, WebSocket.OPEN);
  assert.equal(listRegisteredDevices("account:a")[0].status, "online");
});
