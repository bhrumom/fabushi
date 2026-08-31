import assert from "node:assert/strict";
import test from "node:test";
import { generateKeyPairSync, randomBytes } from "node:crypto";
import { bindDirectProbeEndpoint } from "../lib/device-direct-path.js";
import { attachDirectRpcTransport } from "../lib/device-direct-transport.js";
import { createInvocationDeduper } from "../lib/device-direct-rpc.js";
import { meshIdentityFingerprint } from "../lib/device-mesh.js";

function identity() {
  const pair = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  return {
    publicKey: pair.publicKey.export({ format: "jwk" }),
    privateKeyPem: pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
  };
}

test("two nodes execute call/result over authenticated encrypted UDP", async (t) => {
  const leftIdentity = identity();
  const rightIdentity = identity();
  const leftGeneration = "left-generation-123456";
  const rightGeneration = "right-generation-123456";
  const peers = new Map([
    ["left", { deviceId: "left", generation: leftGeneration, nodeKeyFingerprint: meshIdentityFingerprint(leftIdentity.publicKey) }],
    ["right", { deviceId: "right", generation: rightGeneration, nodeKeyFingerprint: meshIdentityFingerprint(rightIdentity.publicKey) }],
  ]);
  const leftEndpoint = await bindDirectProbeEndpoint({
    identity: leftIdentity,
    deviceId: "left",
    generation: leftGeneration,
    host: "127.0.0.1",
    expectedPeer: (id) => id === "right" ? { fromDeviceId: "right", fromGeneration: rightGeneration, nodeKeyFingerprint: peers.get("right").nodeKeyFingerprint } : null,
  });
  const rightEndpoint = await bindDirectProbeEndpoint({
    identity: rightIdentity,
    deviceId: "right",
    generation: rightGeneration,
    host: "127.0.0.1",
    expectedPeer: (id) => id === "left" ? { fromDeviceId: "left", fromGeneration: leftGeneration, nodeKeyFingerprint: peers.get("left").nodeKeyFingerprint } : null,
  });
  const dedupe = createInvocationDeduper();
  let executions = 0;
  const left = attachDirectRpcTransport({
    endpoint: leftEndpoint,
    identity: leftIdentity,
    accountBinding: "account-binding-test",
    deviceId: "left",
    generation: leftGeneration,
    peerLookup: (id) => peers.get(id),
  });
  const right = attachDirectRpcTransport({
    endpoint: rightEndpoint,
    identity: rightIdentity,
    accountBinding: "account-binding-test",
    deviceId: "right",
    generation: rightGeneration,
    peerLookup: (id) => peers.get(id),
    executeInvocation: (invocationId, toolName, args) => dedupe.run(invocationId, async () => {
      executions += 1;
      return { structuredContent: { toolName, echoed: args.value, executions } };
    }),
  });
  t.after(() => { left.close(); right.close(); leftEndpoint.close(); rightEndpoint.close(); });

  const candidate = { host: "127.0.0.1", port: rightEndpoint.address.port };
  const invocationId = `invocation-${randomBytes(12).toString("hex")}`;
  const response = await left.call({
    peer: peers.get("right"),
    candidate,
    toolName: "fabushi.app.status",
    arguments: { value: "hello" },
    invocationId,
    timeoutMs: 2_000,
  });
  assert.equal(response.route, "direct-udp");
  assert.deepEqual(response.result.structuredContent, { toolName: "fabushi.app.status", echoed: "hello", executions: 1 });
  assert.equal(executions, 1);
  assert.ok(left.sessionFor("right")?.sessionId);
  assert.ok(right.sessionFor("left")?.sessionId);
});

test("same invocation id remains exactly-once when a caller retries after a lost direct response", async (t) => {
  const leftIdentity = identity();
  const rightIdentity = identity();
  const leftGeneration = "left-generation-retry-123";
  const rightGeneration = "right-generation-retry-123";
  const leftPeer = { deviceId: "left", generation: leftGeneration, nodeKeyFingerprint: meshIdentityFingerprint(leftIdentity.publicKey) };
  const rightPeer = { deviceId: "right", generation: rightGeneration, nodeKeyFingerprint: meshIdentityFingerprint(rightIdentity.publicKey) };
  const leftEndpoint = await bindDirectProbeEndpoint({ identity: leftIdentity, deviceId: "left", generation: leftGeneration, host: "127.0.0.1", expectedPeer: (id) => id === "right" ? { fromDeviceId: "right", fromGeneration: rightGeneration, nodeKeyFingerprint: rightPeer.nodeKeyFingerprint } : null });
  const rightEndpoint = await bindDirectProbeEndpoint({ identity: rightIdentity, deviceId: "right", generation: rightGeneration, host: "127.0.0.1", expectedPeer: (id) => id === "left" ? { fromDeviceId: "left", fromGeneration: leftGeneration, nodeKeyFingerprint: leftPeer.nodeKeyFingerprint } : null });
  const dedupe = createInvocationDeduper();
  let executions = 0;
  const left = attachDirectRpcTransport({ endpoint: leftEndpoint, identity: leftIdentity, accountBinding: "account-binding-test", deviceId: "left", generation: leftGeneration, peerLookup: (id) => id === "right" ? rightPeer : null });
  const right = attachDirectRpcTransport({ endpoint: rightEndpoint, identity: rightIdentity, accountBinding: "account-binding-test", deviceId: "right", generation: rightGeneration, peerLookup: (id) => id === "left" ? leftPeer : null, executeInvocation: (id) => dedupe.run(id, async () => ({ structuredContent: { executions: ++executions } })) });
  t.after(() => { left.close(); right.close(); leftEndpoint.close(); rightEndpoint.close(); });

  const invocationId = "invocation-retry-exactly-once";
  const candidate = { host: "127.0.0.1", port: rightEndpoint.address.port };
  const first = await left.call({ peer: rightPeer, candidate, toolName: "side.effect", invocationId, timeoutMs: 2_000 });
  const second = await left.call({ peer: rightPeer, candidate, toolName: "side.effect", invocationId, timeoutMs: 2_000 });
  assert.equal(executions, 1);
  assert.equal(first.result.structuredContent.executions, 1);
  assert.equal(second.result.structuredContent.executions, 1);
});
