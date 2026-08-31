import { randomBytes } from "node:crypto";

export const DEVICE_IDENTITY_REGISTRY_VERSION = 1;
export const DEVICE_IDENTITY_CLAIM_TTL_MS = 10 * 60 * 1000;

const DEFAULT_MAX_BINDINGS = 10_000;
const DEFAULT_MAX_CLAIMS = 1_000;
const DEVICE_ID = /^[A-Za-z0-9._:-]{1,128}$/u;
const FINGERPRINT = /^[A-Za-z0-9_-]{20,128}$/u;
const CLAIM_ID = /^[A-Za-z0-9_-]{24,128}$/u;

function boundedText(value, maximum) {
  return String(value ?? "").trim().slice(0, maximum);
}

function accountId(value) {
  const normalized = boundedText(value, 300);
  if (!normalized || /[\u0000-\u001f\u007f]/u.test(normalized)) {
    throw new Error("invalid device identity account id");
  }
  return normalized;
}

function deviceId(value) {
  const normalized = boundedText(value, 128);
  if (!DEVICE_ID.test(normalized)) throw new Error("invalid device identity device id");
  return normalized;
}

function fingerprint(value) {
  const normalized = boundedText(value, 128);
  if (!FINGERPRINT.test(normalized)) throw new Error("invalid device identity fingerprint");
  return normalized;
}

function dateMilliseconds(value, fallback) {
  const normalized = Number(value);
  return Number.isSafeInteger(normalized) && normalized > 0 ? normalized : fallback;
}

function bindingKey(account, device) {
  return `${account}\0${device}`;
}

function publicBinding(binding) {
  return {
    version: DEVICE_IDENTITY_REGISTRY_VERSION,
    deviceId: binding.deviceId,
    nodeKeyFingerprint: binding.nodeKeyFingerprint,
    status: binding.revokedAt ? "revoked" : "active",
    platform: binding.platform,
    name: binding.name,
    firstSeenAt: new Date(binding.firstSeenAt).toISOString(),
    lastSeenAt: new Date(binding.lastSeenAt).toISOString(),
    rotatedAt: binding.rotatedAt ? new Date(binding.rotatedAt).toISOString() : null,
    revokedAt: binding.revokedAt ? new Date(binding.revokedAt).toISOString() : null,
    rotationCount: binding.rotationCount,
  };
}

function publicClaim(claim) {
  return {
    claimId: claim.claimId,
    deviceId: claim.deviceId,
    currentFingerprint: claim.currentFingerprint || null,
    requestedFingerprint: claim.requestedFingerprint,
    reason: claim.reason,
    platform: claim.platform,
    name: claim.name,
    createdAt: new Date(claim.createdAt).toISOString(),
    expiresAt: new Date(claim.expiresAt).toISOString(),
  };
}

function normalizeStoredBinding(value, timestamp) {
  try {
    const normalizedAccountId = accountId(value?.accountId);
    const normalizedDeviceId = deviceId(value?.deviceId);
    const normalizedFingerprint = fingerprint(value?.nodeKeyFingerprint);
    const firstSeenAt = dateMilliseconds(value?.firstSeenAt, timestamp);
    const lastSeenAt = Math.max(firstSeenAt, dateMilliseconds(value?.lastSeenAt, firstSeenAt));
    const rotatedAt = Number(value?.rotatedAt) > 0 ? Number(value.rotatedAt) : null;
    const revokedAt = Number(value?.revokedAt) > 0 ? Number(value.revokedAt) : null;
    return {
      version: DEVICE_IDENTITY_REGISTRY_VERSION,
      accountId: normalizedAccountId,
      deviceId: normalizedDeviceId,
      nodeKeyFingerprint: normalizedFingerprint,
      platform: boundedText(value?.platform, 80) || "unknown",
      name: boundedText(value?.name, 200) || normalizedDeviceId,
      firstSeenAt,
      lastSeenAt,
      rotatedAt,
      revokedAt,
      rotationCount: Math.max(0, Math.min(Number(value?.rotationCount) || 0, Number.MAX_SAFE_INTEGER)),
    };
  } catch {
    return null;
  }
}

/**
 * Account-scoped trust-on-first-use node registry with explicit key rotation.
 *
 * A valid self-signature proves possession of the presented key. This registry
 * adds continuity: after the first successful enrollment, a different key for
 * the same account/device is rejected and surfaced as a short-lived approval
 * claim. Revocation creates a tombstone, so the old key cannot immediately
 * re-enroll itself after an operator removes trust.
 */
export function createDeviceIdentityRegistry(options = {}) {
  const now = options.now ?? Date.now;
  const randomId = options.randomId ?? (() => randomBytes(24).toString("base64url"));
  const maxBindings = Math.max(1, Number(options.maxBindings) || DEFAULT_MAX_BINDINGS);
  const maxClaims = Math.max(1, Number(options.maxClaims) || DEFAULT_MAX_CLAIMS);
  const claimTtlMs = Math.max(60_000, Number(options.claimTtlMs) || DEVICE_IDENTITY_CLAIM_TTL_MS);
  const bindings = new Map();
  const claims = new Map();

  function cleanup() {
    const timestamp = now();
    for (const [claimIdValue, claim] of claims) {
      if (claim.expiresAt <= timestamp) claims.delete(claimIdValue);
    }
  }

  function removeClaimsForDevice(normalizedAccountId, normalizedDeviceId) {
    for (const [claimIdValue, claim] of claims) {
      if (claim.accountId === normalizedAccountId && claim.deviceId === normalizedDeviceId) {
        claims.delete(claimIdValue);
      }
    }
  }

  function fingerprintOwner(normalizedAccountId, normalizedFingerprint, exceptDeviceId = "") {
    for (const binding of bindings.values()) {
      if (binding.accountId !== normalizedAccountId
          || binding.deviceId === exceptDeviceId
          || binding.revokedAt
          || binding.nodeKeyFingerprint !== normalizedFingerprint) continue;
      return binding;
    }
    return null;
  }

  function load(entries) {
    bindings.clear();
    claims.clear();
    const timestamp = now();
    for (const raw of Array.isArray(entries) ? entries.slice(-maxBindings) : []) {
      const binding = normalizeStoredBinding(raw, timestamp);
      if (!binding) continue;
      const key = bindingKey(binding.accountId, binding.deviceId);
      if (bindings.has(key)) continue;
      if (fingerprintOwner(binding.accountId, binding.nodeKeyFingerprint, binding.deviceId)) continue;
      bindings.set(key, binding);
    }
    return bindings.size;
  }

  function snapshot() {
    return [...bindings.values()]
      .sort((left, right) => left.accountId.localeCompare(right.accountId) || left.deviceId.localeCompare(right.deviceId))
      .map((binding) => ({ ...binding }));
  }

  function createOrReuseClaim({
    normalizedAccountId,
    normalizedDeviceId,
    currentFingerprint,
    requestedFingerprint,
    reason,
    platform,
    name,
  }) {
    cleanup();
    for (const claim of claims.values()) {
      if (claim.accountId === normalizedAccountId
          && claim.deviceId === normalizedDeviceId
          && claim.requestedFingerprint === requestedFingerprint
          && claim.reason === reason) {
        return { claim, changed: false };
      }
    }
    if (claims.size >= maxClaims) {
      const oldest = [...claims.values()].sort((left, right) => left.createdAt - right.createdAt)[0];
      if (oldest) claims.delete(oldest.claimId);
    }
    const claimIdValue = boundedText(randomId(), 128);
    if (!CLAIM_ID.test(claimIdValue)) throw new Error("invalid generated device identity claim id");
    const createdAt = now();
    const claim = {
      claimId: claimIdValue,
      accountId: normalizedAccountId,
      deviceId: normalizedDeviceId,
      currentFingerprint,
      requestedFingerprint,
      reason,
      platform,
      name,
      createdAt,
      expiresAt: createdAt + claimTtlMs,
    };
    claims.set(claimIdValue, claim);
    return { claim, changed: true };
  }

  function authorize(input) {
    cleanup();
    const normalizedAccountId = accountId(input?.accountId);
    const normalizedDeviceId = deviceId(input?.deviceId);
    const normalizedFingerprint = fingerprint(input?.nodeKeyFingerprint);
    const platform = boundedText(input?.platform, 80) || "unknown";
    const name = boundedText(input?.name, 200) || normalizedDeviceId;
    const duplicate = fingerprintOwner(normalizedAccountId, normalizedFingerprint, normalizedDeviceId);
    if (duplicate) {
      return {
        accepted: false,
        status: "rejected",
        code: "node_identity_already_bound",
        changed: false,
      };
    }

    const key = bindingKey(normalizedAccountId, normalizedDeviceId);
    const current = bindings.get(key);
    const timestamp = now();
    if (!current) {
      if (bindings.size >= maxBindings) {
        return { accepted: false, status: "rejected", code: "device_identity_capacity_reached", changed: false };
      }
      const enrolled = {
        version: DEVICE_IDENTITY_REGISTRY_VERSION,
        accountId: normalizedAccountId,
        deviceId: normalizedDeviceId,
        nodeKeyFingerprint: normalizedFingerprint,
        platform,
        name,
        firstSeenAt: timestamp,
        lastSeenAt: timestamp,
        rotatedAt: null,
        revokedAt: null,
        rotationCount: 0,
      };
      bindings.set(key, enrolled);
      removeClaimsForDevice(normalizedAccountId, normalizedDeviceId);
      return {
        accepted: true,
        status: "enrolled",
        bindingVersion: DEVICE_IDENTITY_REGISTRY_VERSION,
        binding: publicBinding(enrolled),
        changed: true,
      };
    }

    if (!current.revokedAt && current.nodeKeyFingerprint === normalizedFingerprint) {
      current.lastSeenAt = timestamp;
      current.platform = platform;
      current.name = name;
      return {
        accepted: true,
        status: "verified",
        bindingVersion: DEVICE_IDENTITY_REGISTRY_VERSION,
        binding: publicBinding(current),
        changed: true,
      };
    }

    const reason = current.revokedAt
      ? "device_identity_reapproval_required"
      : "device_identity_rotation_required";
    const pending = createOrReuseClaim({
      normalizedAccountId,
      normalizedDeviceId,
      currentFingerprint: current.nodeKeyFingerprint,
      requestedFingerprint: normalizedFingerprint,
      reason,
      platform,
      name,
    });
    return {
      accepted: false,
      status: "rotation-pending",
      code: reason,
      claim: publicClaim(pending.claim),
      changed: pending.changed,
    };
  }

  function listBindings(requestedAccountId) {
    cleanup();
    const normalizedAccountId = accountId(requestedAccountId);
    return [...bindings.values()]
      .filter((binding) => binding.accountId === normalizedAccountId)
      .sort((left, right) => left.deviceId.localeCompare(right.deviceId))
      .map(publicBinding);
  }

  function listClaims(requestedAccountId) {
    cleanup();
    const normalizedAccountId = accountId(requestedAccountId);
    return [...claims.values()]
      .filter((claim) => claim.accountId === normalizedAccountId)
      .sort((left, right) => left.createdAt - right.createdAt)
      .map(publicClaim);
  }

  function approve(requestedAccountId, requestedClaimId) {
    cleanup();
    const normalizedAccountId = accountId(requestedAccountId);
    const normalizedClaimId = boundedText(requestedClaimId, 128);
    if (!CLAIM_ID.test(normalizedClaimId)) throw new Error("invalid device identity claim id");
    const claim = claims.get(normalizedClaimId);
    if (!claim || claim.accountId !== normalizedAccountId) {
      throw new Error("unknown or expired device identity claim");
    }
    const duplicate = fingerprintOwner(normalizedAccountId, claim.requestedFingerprint, claim.deviceId);
    if (duplicate) throw new Error("requested node identity is already bound to another device");
    const key = bindingKey(normalizedAccountId, claim.deviceId);
    const current = bindings.get(key);
    if (!current) throw new Error("device identity binding disappeared before approval");
    const timestamp = now();
    const previousFingerprint = current.nodeKeyFingerprint;
    current.nodeKeyFingerprint = claim.requestedFingerprint;
    current.platform = claim.platform;
    current.name = claim.name;
    current.lastSeenAt = timestamp;
    current.rotatedAt = timestamp;
    current.revokedAt = null;
    current.rotationCount += 1;
    removeClaimsForDevice(normalizedAccountId, claim.deviceId);
    return {
      binding: publicBinding(current),
      previousFingerprint,
      changed: true,
    };
  }

  function revoke(requestedAccountId, requestedDeviceId) {
    cleanup();
    const normalizedAccountId = accountId(requestedAccountId);
    const normalizedDeviceId = deviceId(requestedDeviceId);
    const current = bindings.get(bindingKey(normalizedAccountId, normalizedDeviceId));
    if (!current) return { revoked: false, binding: null, changed: false };
    current.revokedAt = now();
    current.lastSeenAt = current.revokedAt;
    removeClaimsForDevice(normalizedAccountId, normalizedDeviceId);
    return { revoked: true, binding: publicBinding(current), changed: true };
  }

  return Object.freeze({
    load,
    snapshot,
    cleanup,
    authorize,
    listBindings,
    listClaims,
    approve,
    revoke,
  });
}
