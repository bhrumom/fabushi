import assert from "node:assert/strict";
import { createHash, generateKeyPairSync } from "node:crypto";
import { createServer } from "node:http";
import test from "node:test";
import WebSocket from "ws";
import {
  attachDeviceGateway,
  callRegisteredDevice,
  resetDeviceGatewayStateForTests,
} from "../lib/device-gateway.js";
import { buildSignedMeshRegistration, canonicalMeshJson } from "../lib/device-mesh.js";

function listen(server) {
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server.address().port)));
}
function opened(ws) {
  return new Promise((resolve, reject) => { ws.once("open", resolve); ws.once("error", reject); });
}
function nextJson(ws) {
  return new Promise((resolve, reject) => {
    ws.once("message", (raw) => { try { resolve(JSON.parse(raw.toString("utf8"))); } catch (error) { reject(error); } });
    ws.once("error", reject);
  });
}
function identity() {
  const pair = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  return {
    publicKey: pair.publicKey.export({ format: "jwk" }),
    privateKeyPem: pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
  };
}
function descriptor() {
  return { name: "computer_state", inputSchema: { type: "object", properties: {}, additionalProperties: false }, outputSchema: { type: "object" } };
}

test("gateway routes through a healthy peer then retries the same invocation over relay", async (t) => {
  resetDeviceGatewayStateForTests();
  const server = createServer((_req, res) => res.writeHead(404).end());
  const gateway = attachDeviceGateway(server, {
    resolveAccount: async (token) => token === "token-a" ? { userId: "account:a" } : null,
    defaultLeaseSeconds: 60,
  });
  const port = await listen(server);
  const router = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer token-a" } });
  const target = new WebSocket(`ws://127.0.0.1:${port}/agent`, { headers: { Authorization: "Bearer token-a" } });
  t.after(async () => {
    router.terminate();
    target.terminate();
    await gateway.close();
    await new Promise((resolve) => server.close(resolve));
    resetDeviceGatewayStateForTests();
  });
  await Promise.all([opened(router), opened(target)]);

  const routerIdentity = identity();
  const targetIdentity = identity();
  const routerGeneration = "router-generation-123456";
  const targetGeneration = "target-generation-123456";
  const tool = descriptor();
  const catalogVersion = createHash("sha256").update(canonicalMeshJson([tool])).digest("hex");

  const sendRegistration = (ws, deviceId, generation, nodeIdentity, directPort) => ws.send(JSON.stringify({
    type: "register",
    deviceId,
    generation,
    name: deviceId,
    platform: "linux",
    capabilities: [tool.name],
    tools: [tool],
    mesh: buildSignedMeshRegistration({ identity: nodeIdentity, deviceId, generation, toolSchemaVersion: catalogVersion }),
    direct: {
      version: "fabushi.direct-path.v1",
      candidates: [{ id: `${deviceId}-candidate`, host: "127.0.0.1", port: directPort, scope: "host", priority: 500 }],
    },
  }));

  sendRegistration(router, "router", routerGeneration, routerIdentity, 41001);
  sendRegistration(target, "target", targetGeneration, targetIdentity, 41002);

  async function waitRegistered(ws) {
    for (let i = 0; i < 8; i += 1) {
      const message = await nextJson(ws);
      if (message.type === "registered") return message;
    }
    throw new Error("missing registered acknowledgement");
  }
  await Promise.all([waitRegistered(router), waitRegistered(target)]);

  router.send(JSON.stringify({
    type: "direct_path_health",
    targetDeviceId: "target",
    candidateId: "udp:host:127.0.0.1:41002",
    reachable: true,
    latencyMs: 4,
    loss: 0,
  }));
  await new Promise((resolve) => setTimeout(resolve, 20));

  const forwardedPromise = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("missing direct_forward_call")), 2_000);
    const handler = (raw) => {
      const message = JSON.parse(raw.toString("utf8"));
      if (message.type !== "direct_forward_call") return;
      clearTimeout(timer);
      router.off("message", handler);
      resolve(message);
    };
    router.on("message", handler);
  });
  const callPromise = callRegisteredDevice("account:a", "target", "computer_state", { source: "gateway-test" }, 5);
  const forwarded = await forwardedPromise;
  assert.equal(forwarded.targetDeviceId, "target");
  assert.match(forwarded.invocationId, /^[a-f0-9]{32}$/u);

  router.send(JSON.stringify({
    type: "direct_forward_failed",
    requestId: forwarded.requestId,
    invocationId: forwarded.invocationId,
    error: "forced direct failure",
  }));

  const relayCall = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("missing relay fallback call")), 2_000);
    const handler = (raw) => {
      const message = JSON.parse(raw.toString("utf8"));
      if (message.type !== "call") return;
      clearTimeout(timer);
      target.off("message", handler);
      resolve(message);
    };
    target.on("message", handler);
  });
  assert.equal(relayCall.invocationId, forwarded.invocationId);
  assert.equal(relayCall.requestId, forwarded.requestId);

  target.send(JSON.stringify({
    type: "result",
    requestId: relayCall.requestId,
    invocationId: relayCall.invocationId,
    ok: true,
    result: { structuredContent: { path: "relay-after-direct-failure" } },
  }));
  const result = await callPromise;
  assert.equal(result.route, "relay");
  assert.deepEqual(result.result.structuredContent, { path: "relay-after-direct-failure" });
});
