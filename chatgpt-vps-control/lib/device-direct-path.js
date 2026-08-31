import {
  createCipheriv,
  createDecipheriv,
  createPrivateKey,
  createPublicKey,
  diffieHellman,
  hkdfSync,
  randomBytes,
  sign,
  verify,
} from "node:crypto";
import dgram from "node:dgram";
import { isIP } from "node:net";
import { networkInterfaces } from "node:os";
import { meshIdentityFingerprint } from "./device-mesh.js";

export const DIRECT_PATH_PROTOCOL_VERSION = "fabushi.direct-path.v1";
export const DIRECT_PATH_TRANSPORT = "udp";
export const RELAY_PATH = "relay";
export const DIRECT_PATH = "direct-udp";

const DEFAULT_CANDIDATE_TTL_MS = 120_000;
const DEFAULT_HEALTH_TTL_MS = 45_000;
const MAX_CANDIDATES_PER_DEVICE = 24;
const MAX_PACKET_BYTES = 60 * 1024;

function bounded(value, maximum) {
  return String(value ?? "").trim().slice(0, maximum);
}

function base64url(value) {
  return Buffer.from(value).toString("base64url");
}

function canonical(value) {
  if (value === null) return "null";
  if (typeof value === "string" || typeof value === "boolean" || typeof value === "number") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}`;
  throw new Error("unsupported direct-path canonical value");
}

function candidateId(candidate) {
  return `${candidate.transport}:${candidate.scope}:${candidate.host}:${candidate.port}`;
}

export function normalizeDirectCandidate(value, now = Date.now(), ttlMs = DEFAULT_CANDIDATE_TTL_MS) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const transport = bounded(value.transport || DIRECT_PATH_TRANSPORT, 16);
  const scope = bounded(value.scope || "host", 16);
  const host = bounded(value.host, 80);
  const port = Number(value.port);
  if (transport !== DIRECT_PATH_TRANSPORT || !["host", "srflx"].includes(scope) || !isIP(host)) return null;
  if (!Number.isSafeInteger(port) || port < 1 || port > 65535) return null;
  const priority = Math.max(0, Math.min(1_000_000, Number(value.priority) || (scope === "host" ? 200 : 100)));
  const observedAt = Number.isFinite(Number(value.observedAt)) ? Number(value.observedAt) : now;
  const expiresAt = Math.min(
    Number.isFinite(Number(value.expiresAt)) ? Number(value.expiresAt) : observedAt + ttlMs,
    now + ttlMs,
  );
  if (expiresAt <= now - 5_000) return null;
  const candidate = { transport, scope, host, port, priority, observedAt, expiresAt };
  return { id: candidateId(candidate), ...candidate };
}

export function collectHostUdpCandidates(port, options = {}) {
  const now = options.now ?? Date.now();
  const interfaces = options.interfaces ?? networkInterfaces();
  const result = [];
  for (const entries of Object.values(interfaces)) {
    for (const entry of entries ?? []) {
      if (entry.internal || !isIP(entry.address)) continue;
      const normalized = normalizeDirectCandidate({
        transport: DIRECT_PATH_TRANSPORT,
        scope: "host",
        host: entry.address,
        port,
        priority: entry.family === "IPv6" || entry.family === 6 ? 180 : 200,
      }, now);
      if (normalized) result.push(normalized);
    }
  }
  return [...new Map(result.map((candidate) => [candidate.id, candidate])).values()].slice(0, MAX_CANDIDATES_PER_DEVICE);
}

export function createDirectPathRegistry(options = {}) {
  const now = options.now ?? Date.now;
  const candidateTtlMs = Number(options.candidateTtlMs) || DEFAULT_CANDIDATE_TTL_MS;
  const healthTtlMs = Number(options.healthTtlMs) || DEFAULT_HEALTH_TTL_MS;
  const devices = new Map();

  function key(accountId, deviceId) {
    return `${bounded(accountId, 300)}\0${bounded(deviceId, 128)}`;
  }

  function cleanup() {
    const timestamp = now();
    for (const [registryKey, device] of devices) {
      device.candidates = device.candidates.filter((candidate) => candidate.expiresAt > timestamp);
      if (device.expiresAt <= timestamp) devices.delete(registryKey);
    }
  }

  function update({ accountId, deviceId, generation, nodeKeyFingerprint, candidates, leaseExpiresAt }) {
    cleanup();
    const normalizedAccount = bounded(accountId, 300);
    const normalizedDevice = bounded(deviceId, 128);
    const normalizedGeneration = bounded(generation, 128);
    if (!normalizedAccount || !normalizedDevice || !normalizedGeneration || !nodeKeyFingerprint) throw new Error("invalid direct path device registration");
    const timestamp = now();
    const normalizedCandidates = [...new Map((Array.isArray(candidates) ? candidates : [])
      .map((candidate) => normalizeDirectCandidate(candidate, timestamp, candidateTtlMs))
      .filter(Boolean)
      .slice(0, MAX_CANDIDATES_PER_DEVICE)
      .map((candidate) => [candidate.id, candidate])).values()];
    const current = devices.get(key(normalizedAccount, normalizedDevice));
    const sameGeneration = current?.generation === normalizedGeneration;
    const health = sameGeneration ? current.health : new Map();
    const entry = {
      accountId: normalizedAccount,
      deviceId: normalizedDevice,
      generation: normalizedGeneration,
      nodeKeyFingerprint: bounded(nodeKeyFingerprint, 128),
      candidates: normalizedCandidates,
      health,
      expiresAt: Math.max(timestamp + 30_000, Number(leaseExpiresAt) || timestamp + candidateTtlMs),
    };
    devices.set(key(normalizedAccount, normalizedDevice), entry);
    return publicEntry(entry, timestamp, healthTtlMs);
  }

  function reportHealth({ accountId, deviceId, generation, candidateId: id, reachable, latencyMs, loss = 0 }) {
    cleanup();
    const entry = devices.get(key(accountId, deviceId));
    if (!entry || entry.generation !== generation) return false;
    const candidate = entry.candidates.find((item) => item.id === id);
    if (!candidate) return false;
    entry.health.set(id, {
      reachable: reachable === true,
      latencyMs: Math.max(0, Math.min(60_000, Number(latencyMs) || 0)),
      loss: Math.max(0, Math.min(1, Number(loss) || 0)),
      checkedAt: now(),
    });
    return true;
  }

  function peers(accountId, requesterDeviceId) {
    cleanup();
    const timestamp = now();
    return [...devices.values()]
      .filter((entry) => entry.accountId === accountId && entry.deviceId !== requesterDeviceId)
      .map((entry) => publicEntry(entry, timestamp, healthTtlMs));
  }

  function select(accountId, deviceId) {
    cleanup();
    const entry = devices.get(key(accountId, deviceId));
    if (!entry) return { path: RELAY_PATH, reason: "device-not-in-direct-registry", candidate: null };
    const timestamp = now();
    const scored = entry.candidates.map((candidate) => {
      const health = entry.health.get(candidate.id);
      const fresh = health && health.checkedAt + healthTtlMs > timestamp;
      if (!fresh || !health.reachable) return null;
      const score = candidate.priority - Math.min(50_000, health.latencyMs) - Math.round(health.loss * 100_000);
      return { candidate, health, score };
    }).filter(Boolean).sort((left, right) => right.score - left.score);
    if (!scored.length) return { path: RELAY_PATH, reason: "no-healthy-direct-candidate", candidate: null };
    return { path: DIRECT_PATH, reason: "healthy-authenticated-direct-candidate", candidate: scored[0].candidate, health: scored[0].health };
  }

  return Object.freeze({ update, reportHealth, peers, select, cleanup });
}

function publicEntry(entry, timestamp, healthTtlMs) {
  return {
    deviceId: entry.deviceId,
    generation: entry.generation,
    nodeKeyFingerprint: entry.nodeKeyFingerprint,
    candidates: entry.candidates.map((candidate) => {
      const health = entry.health.get(candidate.id);
      return {
        ...candidate,
        health: health && health.checkedAt + healthTtlMs > timestamp ? { ...health } : null,
      };
    }),
  };
}

function probePayload(packet) {
  return canonical({
    protocolVersion: DIRECT_PATH_PROTOCOL_VERSION,
    type: packet.type,
    fromDeviceId: packet.fromDeviceId,
    fromGeneration: packet.fromGeneration,
    toDeviceId: packet.toDeviceId,
    nonce: packet.nonce,
    sentAt: packet.sentAt,
    nodePublicKey: packet.nodePublicKey,
  });
}

export function buildSignedDirectProbe({ identity, fromDeviceId, fromGeneration, toDeviceId, nonce = base64url(randomBytes(18)), type = "probe" }) {
  if (!["probe", "probe-ack"].includes(type)) throw new Error("invalid direct probe type");
  const packet = {
    protocolVersion: DIRECT_PATH_PROTOCOL_VERSION,
    type,
    fromDeviceId: bounded(fromDeviceId, 128),
    fromGeneration: bounded(fromGeneration, 128),
    toDeviceId: bounded(toDeviceId, 128),
    nonce: bounded(nonce, 128),
    sentAt: Date.now(),
    nodePublicKey: identity.publicKey,
  };
  const signature = sign("sha256", Buffer.from(probePayload(packet)), createPrivateKey(identity.privateKeyPem)).toString("base64url");
  return { ...packet, signature };
}

export function verifyDirectProbe(packet, expected = {}) {
  if (!packet || packet.protocolVersion !== DIRECT_PATH_PROTOCOL_VERSION || !["probe", "probe-ack"].includes(packet.type)) return false;
  if (expected.fromDeviceId && packet.fromDeviceId !== expected.fromDeviceId) return false;
  if (expected.fromGeneration && packet.fromGeneration !== expected.fromGeneration) return false;
  if (expected.toDeviceId && packet.toDeviceId !== expected.toDeviceId) return false;
  if (Math.abs(Date.now() - Number(packet.sentAt)) > 60_000) return false;
  const fingerprint = meshIdentityFingerprint(packet.nodePublicKey);
  if (!fingerprint || (expected.nodeKeyFingerprint && fingerprint !== expected.nodeKeyFingerprint)) return false;
  try {
    return verify(
      "sha256",
      Buffer.from(probePayload(packet)),
      createPublicKey({ key: packet.nodePublicKey, format: "jwk" }),
      Buffer.from(String(packet.signature || ""), "base64url"),
    );
  } catch {
    return false;
  }
}

export function deriveDirectSessionKey({ identity, peerPublicKey, context }) {
  const shared = diffieHellman({
    privateKey: createPrivateKey(identity.privateKeyPem),
    publicKey: createPublicKey({ key: peerPublicKey, format: "jwk" }),
  });
  return Buffer.from(hkdfSync("sha256", shared, Buffer.from(DIRECT_PATH_PROTOCOL_VERSION), Buffer.from(canonical(context)), 32));
}

function associatedData(context, sequence) {
  return Buffer.from(canonical({ protocolVersion: DIRECT_PATH_PROTOCOL_VERSION, context, sequence }));
}

export function sealDirectDatagram({ key, context, sequence, payload }) {
  const body = Buffer.from(JSON.stringify(payload));
  if (body.length > MAX_PACKET_BYTES) throw new Error("direct datagram payload exceeds safe UDP size");
  const nonce = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  cipher.setAAD(associatedData(context, sequence));
  const ciphertext = Buffer.concat([cipher.update(body), cipher.final()]);
  return {
    version: DIRECT_PATH_PROTOCOL_VERSION,
    sequence,
    nonce: nonce.toString("base64url"),
    ciphertext: ciphertext.toString("base64url"),
    tag: cipher.getAuthTag().toString("base64url"),
  };
}

export function openDirectDatagram({ key, context, envelope }) {
  if (envelope?.version !== DIRECT_PATH_PROTOCOL_VERSION || !Number.isSafeInteger(envelope.sequence) || envelope.sequence < 0) throw new Error("invalid direct datagram envelope");
  const decipher = createDecipheriv("aes-256-gcm", key, Buffer.from(envelope.nonce, "base64url"));
  decipher.setAAD(associatedData(context, envelope.sequence));
  decipher.setAuthTag(Buffer.from(envelope.tag, "base64url"));
  const plaintext = Buffer.concat([decipher.update(Buffer.from(envelope.ciphertext, "base64url")), decipher.final()]);
  return JSON.parse(plaintext.toString("utf8"));
}

export async function bindDirectProbeEndpoint({ identity, deviceId, generation, expectedPeer, host = "0.0.0.0", port = 0, onReachable = () => {} }) {
  const socket = dgram.createSocket(isIP(host) === 6 ? "udp6" : "udp4");
  const pending = new Map();
  socket.on("message", (raw, rinfo) => {
    if (raw.length > MAX_PACKET_BYTES) return;
    let packet;
    try { packet = JSON.parse(raw.toString("utf8")); } catch { return; }
    const peer = expectedPeer(packet.fromDeviceId);
    if (!peer || !verifyDirectProbe(packet, { ...peer, toDeviceId: deviceId })) return;
    if (packet.type === "probe") {
      const ack = buildSignedDirectProbe({ identity, fromDeviceId: deviceId, fromGeneration: generation, toDeviceId: packet.fromDeviceId, nonce: packet.nonce, type: "probe-ack" });
      socket.send(Buffer.from(JSON.stringify(ack)), rinfo.port, rinfo.address);
      onReachable({ peerDeviceId: packet.fromDeviceId, address: rinfo.address, port: rinfo.port, latencyMs: Math.max(0, Date.now() - packet.sentAt) });
      return;
    }
    const request = pending.get(packet.nonce);
    if (!request) return;
    pending.delete(packet.nonce);
    clearTimeout(request.timer);
    const result = { peerDeviceId: packet.fromDeviceId, address: rinfo.address, port: rinfo.port, latencyMs: Math.max(0, Date.now() - request.sentAt) };
    request.resolve(result);
    onReachable(result);
  });
  await new Promise((resolve, reject) => {
    socket.once("error", reject);
    socket.bind(port, host, () => { socket.off("error", reject); resolve(); });
  });
  const address = socket.address();
  return {
    address,
    socket,
    async probe({ peer, candidate, timeoutMs = 2_000 }) {
      const nonce = base64url(randomBytes(18));
      const packet = buildSignedDirectProbe({ identity, fromDeviceId: deviceId, fromGeneration: generation, toDeviceId: peer.deviceId, nonce });
      const sentAt = Date.now();
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => { pending.delete(nonce); reject(new Error("direct probe timed out")); }, timeoutMs);
        pending.set(nonce, { resolve, reject, timer, sentAt });
        socket.send(Buffer.from(JSON.stringify(packet)), candidate.port, candidate.host, (error) => {
          if (!error) return;
          clearTimeout(timer);
          pending.delete(nonce);
          reject(error);
        });
      });
    },
    close() {
      for (const request of pending.values()) { clearTimeout(request.timer); request.reject(new Error("direct probe endpoint closed")); }
      pending.clear();
      socket.close();
    },
  };
}

function buildStunBindingRequest(transactionId) {
  const buffer = Buffer.alloc(20);
  buffer.writeUInt16BE(0x0001, 0);
  buffer.writeUInt16BE(0, 2);
  buffer.writeUInt32BE(0x2112A442, 4);
  transactionId.copy(buffer, 8);
  return buffer;
}

export function parseStunBindingResponse(buffer, transactionId) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 20 || buffer.readUInt16BE(0) !== 0x0101 || buffer.readUInt32BE(4) !== 0x2112A442) return null;
  if (!buffer.subarray(8, 20).equals(transactionId)) return null;
  let offset = 20;
  while (offset + 4 <= buffer.length) {
    const type = buffer.readUInt16BE(offset);
    const length = buffer.readUInt16BE(offset + 2);
    const value = buffer.subarray(offset + 4, offset + 4 + length);
    if (type === 0x0020 && value.length >= 8) {
      const family = value[1];
      const port = value.readUInt16BE(2) ^ 0x2112;
      if (family === 0x01 && value.length >= 8) {
        const cookie = Buffer.from([0x21, 0x12, 0xA4, 0x42]);
        const address = [...value.subarray(4, 8)].map((byte, index) => byte ^ cookie[index]).join(".");
        return { host: address, port };
      }
    }
    offset += 4 + Math.ceil(length / 4) * 4;
  }
  return null;
}

export async function discoverServerReflexiveCandidate({ socket, stunHost, stunPort = 3478, timeoutMs = 2_000 }) {
  const transactionId = randomBytes(12);
  const request = buildStunBindingRequest(transactionId);
  const result = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { cleanup(); reject(new Error("STUN binding request timed out")); }, timeoutMs);
    const onMessage = (message) => {
      const mapped = parseStunBindingResponse(message, transactionId);
      if (!mapped) return;
      cleanup();
      resolve(mapped);
    };
    const cleanup = () => { clearTimeout(timer); socket.off("message", onMessage); };
    socket.on("message", onMessage);
    socket.send(request, stunPort, stunHost, (error) => { if (error) { cleanup(); reject(error); } });
  });
  return normalizeDirectCandidate({ transport: DIRECT_PATH_TRANSPORT, scope: "srflx", host: result.host, port: result.port, priority: 120 });
}
