import assert from "node:assert/strict";
import test from "node:test";
import {
  DEVICE_IDENTITY_CLAIM_TTL_MS,
  createDeviceIdentityRegistry,
} from "../lib/device-identity-registry.js";

const accountId = "account:test";
const deviceId = "pixel-9-pro-android";
const firstFingerprint = "first_node_fingerprint_0123456789";
const secondFingerprint = "second_node_fingerprint_012345678";

function fixture() {
  let timestamp = Date.UTC(2026, 7, 31, 0, 0, 0);
  let sequence = 0;
  const registry = createDeviceIdentityRegistry({
    now: () => timestamp,
    randomId: () => `claim_${String(sequence += 1).padStart(32, "0")}`,
  });
  return {
    registry,
    now: () => timestamp,
    advance(milliseconds) { timestamp += milliseconds; },
  };
}

test("first signed node enrolls, the same key verifies, and a new key requires explicit approval", () => {
  const clock = fixture();
  const enrolled = clock.registry.authorize({
    accountId,
    deviceId,
    nodeKeyFingerprint: firstFingerprint,
    platform: "android",
    name: "Pixel 9 Pro",
  });
  assert.equal(enrolled.accepted, true);
  assert.equal(enrolled.status, "enrolled");
  assert.equal(enrolled.binding.status, "active");
  assert.equal(enrolled.binding.rotationCount, 0);

  clock.advance(1_000);
  const verified = clock.registry.authorize({
    accountId,
    deviceId,
    nodeKeyFingerprint: firstFingerprint,
    platform: "android",
    name: "Pixel 9 Pro renamed",
  });
  assert.equal(verified.accepted, true);
  assert.equal(verified.status, "verified");
  assert.equal(verified.binding.name, "Pixel 9 Pro renamed");

  clock.advance(1_000);
  const replacement = clock.registry.authorize({
    accountId,
    deviceId,
    nodeKeyFingerprint: secondFingerprint,
    platform: "android",
    name: "Pixel 9 Pro reinstalled",
  });
  assert.equal(replacement.accepted, false);
  assert.equal(replacement.code, "device_identity_rotation_required");
  assert.equal(clock.registry.listBindings(accountId)[0].nodeKeyFingerprint, firstFingerprint);
  const claims = clock.registry.listClaims(accountId);
  assert.equal(claims.length, 1);
  assert.equal(claims[0].requestedFingerprint, secondFingerprint);
  assert.equal(claims[0].currentFingerprint, firstFingerprint);

  clock.advance(1_000);
  const approved = clock.registry.approve(accountId, claims[0].claimId);
  assert.equal(approved.previousFingerprint, firstFingerprint);
  assert.equal(approved.binding.nodeKeyFingerprint, secondFingerprint);
  assert.equal(approved.binding.rotationCount, 1);
  assert.equal(approved.binding.status, "active");
  assert.equal(clock.registry.listClaims(accountId).length, 0);

  clock.advance(1_000);
  const verifiedReplacement = clock.registry.authorize({
    accountId,
    deviceId,
    nodeKeyFingerprint: secondFingerprint,
    platform: "android",
    name: "Pixel 9 Pro reinstalled",
  });
  assert.equal(verifiedReplacement.accepted, true);
  assert.equal(verifiedReplacement.status, "verified");
});

test("revocation is a tombstone and cannot be bypassed by reconnecting the old key", () => {
  const clock = fixture();
  clock.registry.authorize({ accountId, deviceId, nodeKeyFingerprint: firstFingerprint, platform: "ios" });
  clock.advance(5_000);
  const revoked = clock.registry.revoke(accountId, deviceId);
  assert.equal(revoked.revoked, true);
  assert.equal(revoked.binding.status, "revoked");

  const reconnect = clock.registry.authorize({
    accountId,
    deviceId,
    nodeKeyFingerprint: firstFingerprint,
    platform: "ios",
  });
  assert.equal(reconnect.accepted, false);
  assert.equal(reconnect.code, "device_identity_reapproval_required");
  const [claim] = clock.registry.listClaims(accountId);
  assert.ok(claim);
  const approved = clock.registry.approve(accountId, claim.claimId);
  assert.equal(approved.binding.status, "active");
  assert.equal(approved.binding.rotationCount, 1);
});

test("one active node fingerprint cannot identify two devices in the same account", () => {
  const clock = fixture();
  clock.registry.authorize({
    accountId,
    deviceId: "desktop-one",
    nodeKeyFingerprint: firstFingerprint,
    platform: "linux",
  });
  const duplicate = clock.registry.authorize({
    accountId,
    deviceId: "desktop-two",
    nodeKeyFingerprint: firstFingerprint,
    platform: "linux",
  });
  assert.deepEqual(duplicate, {
    accepted: false,
    status: "rejected",
    code: "node_identity_already_bound",
    changed: false,
  });
  assert.equal(clock.registry.listBindings(accountId).length, 1);
});

test("bindings survive a persistent snapshot while pending approval claims expire", () => {
  const clock = fixture();
  clock.registry.authorize({ accountId, deviceId, nodeKeyFingerprint: firstFingerprint, platform: "android" });
  clock.registry.authorize({ accountId, deviceId, nodeKeyFingerprint: secondFingerprint, platform: "android" });
  const snapshot = clock.registry.snapshot();
  assert.equal(snapshot.length, 1);
  assert.equal(snapshot[0].accountId, accountId);
  assert.equal(clock.registry.listClaims(accountId).length, 1);

  clock.advance(DEVICE_IDENTITY_CLAIM_TTL_MS + 1);
  assert.equal(clock.registry.listClaims(accountId).length, 0);

  const reloaded = createDeviceIdentityRegistry({ now: clock.now });
  assert.equal(reloaded.load([
    ...snapshot,
    { ...snapshot[0], deviceId: "duplicate", nodeKeyFingerprint: firstFingerprint },
    { accountId: "", deviceId: "invalid", nodeKeyFingerprint: "bad" },
  ]), 1);
  const [binding] = reloaded.listBindings(accountId);
  assert.equal(binding.deviceId, deviceId);
  assert.equal(binding.nodeKeyFingerprint, firstFingerprint);
  assert.equal(binding.status, "active");
});
