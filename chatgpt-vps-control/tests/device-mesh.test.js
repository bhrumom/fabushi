import assert from "node:assert/strict";
import { mkdtemp, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  DEVICE_MESH_PROTOCOL_VERSION,
  buildSignedMeshRegistration,
  loadOrCreateMeshIdentity,
  meshIdentityFingerprint,
  publicMeshState,
  verifyAndNormalizeMeshRegistration,
} from "../lib/device-mesh.js";

const context = {
  deviceId: "android-pixel-test",
  generation: "generation_0123456789abcdef",
  toolSchemaVersion: "a".repeat(64),
};

test("device mesh identity is persistent, private and signs its exact registration context", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-device-mesh-"));
  try {
    const identityPath = join(root, "identity.json");
    const first = loadOrCreateMeshIdentity(identityPath);
    const second = loadOrCreateMeshIdentity(identityPath);
    assert.equal(second.fingerprint, first.fingerprint);
    assert.equal(meshIdentityFingerprint(first.publicKey), first.fingerprint);
    if (process.platform !== "win32") {
      assert.equal((await stat(identityPath)).mode & 0o777, 0o600);
    }

    const registration = buildSignedMeshRegistration({
      identity: first,
      ...context,
      tags: ["platform:android", "platform:android", "invalid tag"],
      posture: {
        appVersion: "1.2.3",
        deviceClass: "phone",
        appState: "foreground",
        password: "must-not-be-exported",
      },
    });
    const verified = verifyAndNormalizeMeshRegistration(registration, context);
    assert.equal(verified.protocolVersion, DEVICE_MESH_PROTOCOL_VERSION);
    assert.equal(verified.nodeKeyFingerprint, first.fingerprint);
    assert.equal(verified.signed, true);
    assert.deepEqual(verified.supportedPaths, ["relay"]);
    assert.equal(verified.activePath, "relay");
    assert.deepEqual(verified.tags, ["platform:android"]);
    assert.deepEqual(verified.posture, {
      appVersion: "1.2.3",
      deviceClass: "phone",
      appState: "foreground",
    });

    for (const mutation of [
      { ...context, deviceId: "android-other" },
      { ...context, generation: "generation_changed_abcdef" },
      { ...context, toolSchemaVersion: "b".repeat(64) },
    ]) {
      assert.throws(
        () => verifyAndNormalizeMeshRegistration(registration, mutation),
        /signature verification failed/,
      );
    }

    assert.throws(
      () => verifyAndNormalizeMeshRegistration({ ...registration, nonce: `${registration.nonce}x` }, context),
      /signature verification failed/,
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("legacy device public state is explicit and never claims a signed or direct path", () => {
  assert.deepEqual(publicMeshState(null), {
    protocolVersion: null,
    signed: false,
    identityStatus: "legacy",
    identityBindingVersion: null, // GBF-412 legacy identity test
    supportedPaths: ["relay"],
    preferredPath: "relay",
    activePath: "relay",
    features: ["account-scoped-discovery", "lease-heartbeat", "relay-fallback", "capability-catalog"],
    tags: [],
    posture: {},
  });
});

test("mesh registration rejects unsupported versions and malformed keys", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-device-mesh-invalid-"));
  try {
    const identity = loadOrCreateMeshIdentity(join(root, "identity.json"));
    const registration = buildSignedMeshRegistration({ identity, ...context });
    assert.throws(
      () => verifyAndNormalizeMeshRegistration({ ...registration, protocolVersion: "future.v99" }, context),
      /unsupported mesh protocol version/,
    );
    assert.throws(
      () => verifyAndNormalizeMeshRegistration({ ...registration, nodePublicKey: { kty: "oct" } }, context),
      /invalid signed mesh identity/,
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
