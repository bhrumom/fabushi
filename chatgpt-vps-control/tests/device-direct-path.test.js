import assert from "node:assert/strict";
import { test } from "node:test";
import { generateKeyPairSync } from "node:crypto";
import {
  bindDirectProbeEndpoint,
  createDirectPathRegistry,
  deriveDirectSessionKey,
  normalizeDirectCandidate,
  openDirectDatagram,
  parseStunBindingResponse,
  sealDirectDatagram,
} from "../lib/device-direct-path.js";
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

test("direct path candidates are account-scoped and fail closed to relay", () => {
  let now = 100_000;
  const registry = createDirectPathRegistry({ now: () => now, candidateTtlMs: 30_000, healthTtlMs: 5_000 });
  const candidate = normalizeDirectCandidate({ host: "127.0.0.1", port: 41001, scope: "host", priority: 500 }, now, 30_000);
  registry.update({ accountId: "a", deviceId: "phone", generation: "g-phone-1234567890", nodeKeyFingerprint: "fingerprint-phone-1234567890", candidates: [candidate], leaseExpiresAt: now + 60_000 });
  registry.update({ accountId: "b", deviceId: "other", generation: "g-other-1234567890", nodeKeyFingerprint: "fingerprint-other-1234567890", candidates: [candidate], leaseExpiresAt: now + 60_000 });

  assert.deepEqual(registry.peers("a", "controller").map((peer) => peer.deviceId), ["phone"]);
  assert.equal(registry.select("a", "phone").path, "relay");
  assert.equal(registry.reportHealth({ accountId: "a", deviceId: "phone", generation: "wrong", candidateId: candidate.id, reachable: true, latencyMs: 1 }), false);
  assert.equal(registry.reportHealth({ accountId: "a", deviceId: "phone", generation: "g-phone-1234567890", candidateId: candidate.id, reachable: true, latencyMs: 8 }), true);
  assert.equal(registry.select("a", "phone").path, "direct-udp");

  now += 6_000;
  assert.equal(registry.select("a", "phone").path, "relay");
});

test("two signed nodes prove a real UDP direct path over loopback", async (t) => {
  const leftIdentity = identity();
  const rightIdentity = identity();
  const leftPeer = {
    fromDeviceId: "left",
    fromGeneration: "left-generation-123456",
    nodeKeyFingerprint: meshIdentityFingerprint(leftIdentity.publicKey),
  };
  const rightPeer = {
    fromDeviceId: "right",
    fromGeneration: "right-generation-12345",
    nodeKeyFingerprint: meshIdentityFingerprint(rightIdentity.publicKey),
  };
  const left = await bindDirectProbeEndpoint({
    identity: leftIdentity,
    deviceId: "left",
    generation: leftPeer.fromGeneration,
    host: "127.0.0.1",
    expectedPeer: (deviceId) => deviceId === "right" ? rightPeer : null,
  });
  const right = await bindDirectProbeEndpoint({
    identity: rightIdentity,
    deviceId: "right",
    generation: rightPeer.fromGeneration,
    host: "127.0.0.1",
    expectedPeer: (deviceId) => deviceId === "left" ? leftPeer : null,
  });
  t.after(() => { left.close(); right.close(); });

  const result = await left.probe({
    peer: { deviceId: "right" },
    candidate: { host: "127.0.0.1", port: right.address.port },
    timeoutMs: 2_000,
  });
  assert.equal(result.peerDeviceId, "right");
  assert.equal(result.address, "127.0.0.1");
  assert.ok(result.latencyMs >= 0);
});

test("node keys derive the same AEAD session key and reject tampering", () => {
  const left = identity();
  const right = identity();
  const context = { left: "a", right: "b", leftGeneration: "ga", rightGeneration: "gb" };
  const leftKey = deriveDirectSessionKey({ identity: left, peerPublicKey: right.publicKey, context });
  const rightKey = deriveDirectSessionKey({ identity: right, peerPublicKey: left.publicKey, context });
  assert.deepEqual(leftKey, rightKey);
  const envelope = sealDirectDatagram({ key: leftKey, context, sequence: 7, payload: { type: "call", requestId: "r1", tool: "fabushi.app.status" } });
  assert.deepEqual(openDirectDatagram({ key: rightKey, context, envelope }), { type: "call", requestId: "r1", tool: "fabushi.app.status" });
  const originalTag = Buffer.from(envelope.tag, "base64url");
  const tamperedTag = Buffer.from(originalTag);
  tamperedTag[0] ^= 0x80;
  assert.throws(() => openDirectDatagram({
    key: rightKey,
    context,
    envelope: { ...envelope, tag: tamperedTag.toString("base64url") },
  }));
});

test("STUN XOR-MAPPED-ADDRESS parsing yields a server-reflexive IPv4 endpoint", () => {
  const transactionId = Buffer.from("00112233445566778899aabb", "hex");
  const response = Buffer.alloc(32);
  response.writeUInt16BE(0x0101, 0);
  response.writeUInt16BE(12, 2);
  response.writeUInt32BE(0x2112A442, 4);
  transactionId.copy(response, 8);
  response.writeUInt16BE(0x0020, 20);
  response.writeUInt16BE(8, 22);
  response[25] = 0x01;
  const port = 54321;
  response.writeUInt16BE(port ^ 0x2112, 26);
  const address = [203, 0, 113, 9];
  const cookie = [0x21, 0x12, 0xA4, 0x42];
  address.forEach((byte, index) => { response[28 + index] = byte ^ cookie[index]; });
  assert.deepEqual(parseStunBindingResponse(response, transactionId), { host: "203.0.113.9", port });
});

test("direct RPC transport and exactly-once dedupe are part of the mesh runtime", () => {
  assert.equal(typeof attachDirectRpcTransport, "function");
  assert.equal(typeof createInvocationDeduper, "function");
});

// GBF-412: changing this watched test intentionally gates the full generated direct-forwarding stack.
