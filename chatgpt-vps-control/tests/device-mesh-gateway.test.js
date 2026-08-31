import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import WebSocket from "ws";
import {
  attachDeviceGateway,
  listRegisteredDevices,
  resetDeviceGatewayStateForTests,
} from "../lib/device-gateway.js";
import {
  buildSignedMeshRegistration,
  loadOrCreateMeshIdentity,
} from "../lib/device-mesh.js";

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

function closed(ws) {
  return new Promise((resolve) => ws.once("close", (code, reason) => resolve({ code, reason: reason.toString("utf8") })));
}

async function until(assertion, timeoutMs = 2_000) {
  const deadline = Date.now() + timeoutMs;
  while (true) {
    try { return assertion(); } catch (error) {
      if (Date.now() >= deadline) throw error;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
  }
}

test("gateway exposes verified mesh identity and updates safe heartbeat posture", async (t) => {
  resetDeviceGatewayStateForTests();
  const root = await mkdtemp(join(tmpdir(), "fabushi-gateway-mesh-"));
  const server = createServer((_request, response) => response.writeHead(404).end());
  const gateway = attachDeviceGateway(server, {
    resolveAccount: async (token) => token === "account-token" ? { userId: "account:mesh" } : null,
    requireSignedMesh: true,
    defaultLeaseSeconds: 60,
  });
  const port = await listen(server);
  const socket = new WebSocket(`ws://127.0.0.1:${port}/agent`, {
    headers: { Authorization: "Bearer account-token" },
  });
  t.after(async () => {
    socket.terminate();
    await gateway.close();
    await new Promise((resolve) => server.close(resolve));
    await rm(root, { recursive: true, force: true });
    resetDeviceGatewayStateForTests();
  });
  await opened(socket);

  const descriptor = {
    name: "fabushi.app.status",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    outputSchema: { type: "object" },
  };
  const toolSchemaVersion = createHash("sha256").update(JSON.stringify([descriptor])).digest("hex");
  const generation = "mesh_generation_0123456789abcdef";
  const identity = loadOrCreateMeshIdentity(join(root, "identity.json"));
  const mesh = buildSignedMeshRegistration({
    identity,
    deviceId: "android-mesh-1",
    generation,
    toolSchemaVersion,
    tags: ["platform:android", "role:mobile"],
    posture: { appVersion: "1.0.0", deviceClass: "phone", appState: "foreground" },
  });

  socket.send(JSON.stringify({
    type: "register",
    deviceId: "android-mesh-1",
    name: "Android Mesh Fixture",
    platform: "android",
    generation,
    capabilities: [descriptor.name],
    tools: [descriptor],
    mesh,
  }));
  const registration = await nextJson(socket);
  assert.equal(registration.type, "registered");
  assert.equal(registration.mesh.signed, true);
  assert.equal(registration.mesh.nodeKeyFingerprint, identity.fingerprint);
  assert.equal(registration.mesh.activePath, "relay");

  const listed = listRegisteredDevices("account:mesh");
  assert.equal(listed.length, 1);
  assert.equal(listed[0].mesh.signed, true);
  assert.equal(listed[0].mesh.nodeKeyFingerprint, identity.fingerprint);
  assert.deepEqual(listed[0].mesh.tags, ["platform:android", "role:mobile"]);
  assert.equal(listed[0].mesh.posture.appState, "foreground");
  assert.equal("nodePublicKey" in listed[0].mesh, false);

  socket.send(JSON.stringify({
    type: "heartbeat",
    at: Date.now(),
    mesh: { activePath: "relay", posture: { appState: "background", networkType: "wifi", token: "redact-me" } },
  }));
  await until(() => {
    const current = listRegisteredDevices("account:mesh")[0];
    assert.equal(current.mesh.posture.appState, "background");
    assert.equal(current.mesh.posture.networkType, "wifi");
    assert.equal(current.mesh.posture.token, undefined);
  });
});

test("gateway rejects a tampered signed mesh registration and an unsigned node under strict policy", async (t) => {
  resetDeviceGatewayStateForTests();
  const root = await mkdtemp(join(tmpdir(), "fabushi-gateway-mesh-reject-"));
  const server = createServer((_request, response) => response.writeHead(404).end());
  const gateway = attachDeviceGateway(server, {
    resolveAccount: async () => ({ userId: "account:mesh-reject" }),
    requireSignedMesh: true,
  });
  const port = await listen(server);
  const sockets = [];
  t.after(async () => {
    for (const socket of sockets) socket.terminate();
    await gateway.close();
    await new Promise((resolve) => server.close(resolve));
    await rm(root, { recursive: true, force: true });
    resetDeviceGatewayStateForTests();
  });

  const descriptor = { name: "fabushi.app.status", inputSchema: { type: "object" } };
  const toolSchemaVersion = createHash("sha256").update(JSON.stringify([descriptor])).digest("hex");
  const generation = "mesh_generation_reject_0123456789";
  const identity = loadOrCreateMeshIdentity(join(root, "identity.json"));
  const valid = buildSignedMeshRegistration({
    identity,
    deviceId: "ios-mesh-bad",
    generation,
    toolSchemaVersion,
  });

  const tampered = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer account-token" } });
  sockets.push(tampered);
  await opened(tampered);
  const tamperedClosed = closed(tampered);
  tampered.send(JSON.stringify({
    type: "register",
    deviceId: "ios-mesh-bad",
    name: "Tampered iOS",
    platform: "ios",
    generation,
    capabilities: [descriptor.name],
    tools: [descriptor],
    mesh: { ...valid, signature: `${valid.signature.slice(0, -1)}A` },
  }));
  assert.equal((await tamperedClosed).code, 1008);

  const unsigned = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer account-token" } });
  sockets.push(unsigned);
  await opened(unsigned);
  const unsignedClosed = closed(unsigned);
  unsigned.send(JSON.stringify({
    type: "register",
    deviceId: "legacy-mobile",
    name: "Legacy Mobile",
    platform: "android",
    capabilities: [descriptor.name],
    tools: [descriptor],
  }));
  assert.equal((await unsignedClosed).code, 1008);
  assert.equal(listRegisteredDevices("account:mesh-reject").length, 0);
});
