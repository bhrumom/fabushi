import { createHash } from "node:crypto";
import { DIRECT_PATH_PROTOCOL_VERSION, openDirectDatagram, sealDirectDatagram } from "./device-direct-path.js";

export const DIRECT_RPC_PROTOCOL_VERSION = "fabushi.direct-rpc.v1";
const MAX_REPLAY_WINDOW = 128;
const DEFAULT_DEDUPE_TTL_MS = 10 * 60_000;
const DEFAULT_DEDUPE_ENTRIES = 512;

function bounded(value, maximum) {
  return String(value ?? "").trim().slice(0, maximum);
}

function canonical(value) {
  if (value === null) return "null";
  if (["string", "boolean", "number"].includes(typeof value)) return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}`;
  }
  throw new Error("unsupported direct RPC canonical value");
}

export function buildDirectRpcSessionContext({ accountId, leftDeviceId, leftGeneration, rightDeviceId, rightGeneration }) {
  const account = bounded(accountId, 300);
  const peers = [
    { deviceId: bounded(leftDeviceId, 128), generation: bounded(leftGeneration, 128) },
    { deviceId: bounded(rightDeviceId, 128), generation: bounded(rightGeneration, 128) },
  ].sort((a, b) => `${a.deviceId}\0${a.generation}`.localeCompare(`${b.deviceId}\0${b.generation}`));
  if (!account || peers.some((peer) => !peer.deviceId || !peer.generation) || peers[0].deviceId === peers[1].deviceId) {
    throw new Error("invalid direct RPC session context");
  }
  const binding = { protocolVersion: DIRECT_RPC_PROTOCOL_VERSION, accountId: account, peers };
  const sessionId = createHash("sha256").update(canonical(binding)).digest("base64url").slice(0, 32);
  return Object.freeze({ ...binding, sessionId });
}

export function createReplayWindow(options = {}) {
  const width = Math.max(8, Math.min(1024, Number(options.width) || MAX_REPLAY_WINDOW));
  let highest = -1;
  const seen = new Set();
  return Object.freeze({
    accept(sequence) {
      if (!Number.isSafeInteger(sequence) || sequence < 0) return false;
      if (highest >= 0 && sequence <= highest - width) return false;
      if (seen.has(sequence)) return false;
      seen.add(sequence);
      if (sequence > highest) highest = sequence;
      const floor = highest - width;
      for (const value of seen) if (value <= floor) seen.delete(value);
      return true;
    },
    snapshot() { return { highest, seen: [...seen].sort((a, b) => a - b) }; },
  });
}

function validateRpcPayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) throw new Error("invalid direct RPC payload");
  if (payload.protocolVersion !== DIRECT_RPC_PROTOCOL_VERSION) throw new Error("direct RPC protocol mismatch");
  if (!["call", "result", "error"].includes(payload.kind)) throw new Error("invalid direct RPC message kind");
  const invocationId = bounded(payload.invocationId, 128);
  if (!/^[A-Za-z0-9._:-]{16,128}$/u.test(invocationId)) throw new Error("invalid direct RPC invocation id");
  return { ...payload, invocationId };
}

export function createDirectRpcSession({ key, context, localDeviceId, peerDeviceId, replayWindow }) {
  if (!Buffer.isBuffer(key) || key.length !== 32) throw new Error("direct RPC requires a 32-byte session key");
  if (!context?.sessionId || context.protocolVersion !== DIRECT_RPC_PROTOCOL_VERSION) throw new Error("invalid direct RPC context");
  const local = bounded(localDeviceId, 128);
  const peer = bounded(peerDeviceId, 128);
  if (!local || !peer || local === peer) throw new Error("invalid direct RPC peers");
  let sendSequence = 0;
  const replay = replayWindow ?? createReplayWindow();
  const aad = Object.freeze({
    directProtocolVersion: DIRECT_PATH_PROTOCOL_VERSION,
    rpcProtocolVersion: DIRECT_RPC_PROTOCOL_VERSION,
    accountId: context.accountId,
    sessionId: context.sessionId,
    peers: context.peers,
  });

  return Object.freeze({
    sessionId: context.sessionId,
    seal(message) {
      const normalized = validateRpcPayload({ protocolVersion: DIRECT_RPC_PROTOCOL_VERSION, ...message });
      const sequence = sendSequence++;
      return sealDirectDatagram({
        key,
        context: aad,
        sequence,
        payload: { ...normalized, fromDeviceId: local, toDeviceId: peer, sessionId: context.sessionId },
      });
    },
    open(envelope) {
      // Authenticate before changing the replay state. A forged sequence number must
      // never consume a replay-window slot.
      const payload = validateRpcPayload(openDirectDatagram({ key, context: aad, envelope }));
      if (payload.sessionId !== context.sessionId || payload.fromDeviceId !== peer || payload.toDeviceId !== local) {
        throw new Error("direct RPC peer/session binding mismatch");
      }
      if (!replay.accept(envelope.sequence)) throw new Error("direct RPC replay rejected");
      return payload;
    },
    replaySnapshot() { return replay.snapshot(); },
  });
}

export function createInvocationDeduper(options = {}) {
  const now = options.now ?? Date.now;
  const ttlMs = Math.max(1_000, Number(options.ttlMs) || DEFAULT_DEDUPE_TTL_MS);
  const maxEntries = Math.max(16, Math.min(10_000, Number(options.maxEntries) || DEFAULT_DEDUPE_ENTRIES));
  const entries = new Map();

  function cleanup() {
    const timestamp = now();
    for (const [id, entry] of entries) if (entry.expiresAt <= timestamp && entry.state === "completed") entries.delete(id);
    while (entries.size > maxEntries) {
      const oldest = [...entries.entries()].find(([, entry]) => entry.state === "completed");
      if (!oldest) break;
      entries.delete(oldest[0]);
    }
  }

  async function run(invocationId, execute) {
    const id = bounded(invocationId, 128);
    if (!/^[A-Za-z0-9._:-]{16,128}$/u.test(id)) throw new Error("invalid invocation id");
    cleanup();
    const existing = entries.get(id);
    if (existing) return existing.promise;

    const entry = { state: "running", expiresAt: Number.MAX_SAFE_INTEGER, promise: null };
    const promise = Promise.resolve()
      .then(execute)
      .then(
        (value) => {
          entry.state = "completed";
          entry.expiresAt = now() + ttlMs;
          entry.value = value;
          cleanup();
          return value;
        },
        (error) => {
          // Execution errors are also cached. A fallback transport must not retry an
          // already-executed side effect merely because the tool returned an error.
          entry.state = "completed";
          entry.expiresAt = now() + ttlMs;
          entry.error = error;
          cleanup();
          throw error;
        },
      );
    entry.promise = promise;
    entries.set(id, entry);
    cleanup();
    return promise;
  }

  return Object.freeze({ run, cleanup, size: () => entries.size });
}
