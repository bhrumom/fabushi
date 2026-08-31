import { randomBytes } from "node:crypto";
import {
  DIRECT_PATH_PROTOCOL_VERSION,
  deriveDirectSessionKey,
  verifyDirectProbe,
} from "./device-direct-path.js";
import {
  buildDirectRpcSessionContext,
  createDirectRpcSession,
} from "./device-direct-rpc.js";

export const DIRECT_RPC_PACKET_TYPE = "fabushi-direct-rpc";
const MAX_PACKET_BYTES = 60 * 1024;
const DEFAULT_CALL_TIMEOUT_MS = 2_500;
const MAX_PENDING_CALLS = 32;

function stableInvocationId(value) {
  const id = String(value || randomBytes(16).toString("hex")).trim().slice(0, 128);
  if (!/^[A-Za-z0-9._:-]{16,128}$/u.test(id)) throw new Error("invalid direct invocation id");
  return id;
}

function safePeer(peer) {
  if (!peer?.deviceId || !peer?.generation || !peer?.nodeKeyFingerprint) return null;
  return {
    deviceId: String(peer.deviceId).slice(0, 128),
    generation: String(peer.generation).slice(0, 128),
    nodeKeyFingerprint: String(peer.nodeKeyFingerprint).slice(0, 128),
  };
}

function encodePacket(packet) {
  const bytes = Buffer.from(JSON.stringify(packet));
  if (bytes.length > MAX_PACKET_BYTES) throw new Error("direct RPC packet exceeds UDP payload limit");
  return bytes;
}

export function attachDirectRpcTransport({
  endpoint,
  identity,
  accountBinding,
  deviceId,
  generation,
  peerLookup,
  executeInvocation,
  onPathHealthy = () => {},
}) {
  if (!endpoint?.socket || typeof endpoint.probe !== "function") throw new Error("direct RPC transport requires a bound direct endpoint");
  if (typeof peerLookup !== "function") throw new Error("direct RPC transport requires peer lookup");
  const sessions = new Map();
  const pending = new Map();
  let closed = false;

  function sessionContext(peer) {
    return buildDirectRpcSessionContext({
      accountId: accountBinding,
      leftDeviceId: deviceId,
      leftGeneration: generation,
      rightDeviceId: peer.deviceId,
      rightGeneration: peer.generation,
    });
  }

  function establishFromProbe(packet, rinfo) {
    const peer = safePeer(peerLookup(String(packet?.fromDeviceId || "")));
    if (!peer) return null;
    if (!verifyDirectProbe(packet, {
      fromDeviceId: peer.deviceId,
      fromGeneration: peer.generation,
      toDeviceId: deviceId,
      nodeKeyFingerprint: peer.nodeKeyFingerprint,
    })) return null;
    const context = sessionContext(peer);
    const key = deriveDirectSessionKey({ identity, peerPublicKey: packet.nodePublicKey, context });
    const current = sessions.get(peer.deviceId);
    const rpc = current?.context.sessionId === context.sessionId
      ? current.rpc
      : createDirectRpcSession({ key, context, localDeviceId: deviceId, peerDeviceId: peer.deviceId });
    const session = { peer, context, key, rpc, address: rinfo.address, port: rinfo.port, updatedAt: Date.now() };
    sessions.set(peer.deviceId, session);
    onPathHealthy({ peerDeviceId: peer.deviceId, address: rinfo.address, port: rinfo.port });
    return session;
  }

  function sendOuter(session, envelope, host = session.address, port = session.port) {
    if (!host || !port) throw new Error("direct RPC peer address is unavailable");
    const packet = encodePacket({
      protocolVersion: DIRECT_PATH_PROTOCOL_VERSION,
      type: DIRECT_RPC_PACKET_TYPE,
      fromDeviceId: deviceId,
      fromGeneration: generation,
      toDeviceId: session.peer.deviceId,
      sessionId: session.context.sessionId,
      envelope,
    });
    return new Promise((resolve, reject) => {
      endpoint.socket.send(packet, port, host, (error) => error ? reject(error) : resolve());
    });
  }

  async function handleCall(session, payload, rinfo) {
    if (typeof executeInvocation !== "function") return;
    const invocationId = stableInvocationId(payload.invocationId);
    const toolName = String(payload.toolName || "").slice(0, 128);
    const args = payload.arguments && typeof payload.arguments === "object" && !Array.isArray(payload.arguments) ? payload.arguments : {};
    if (!toolName) return;
    try {
      const result = await executeInvocation(invocationId, toolName, args);
      const envelope = session.rpc.seal({ kind: "result", invocationId, ok: !result?.isError, result });
      await sendOuter(session, envelope, rinfo.address, rinfo.port);
    } catch (error) {
      try {
        const envelope = session.rpc.seal({
          kind: "error",
          invocationId,
          ok: false,
          error: error instanceof Error ? error.message.slice(0, 4_000) : String(error).slice(0, 4_000),
        });
        await sendOuter(session, envelope, rinfo.address, rinfo.port);
      } catch {
        // Oversized or unreachable direct errors are intentionally silent. The caller
        // will retry the same invocation id over relay and receive the cached outcome.
      }
    }
  }

  const onMessage = (raw, rinfo) => {
    if (closed || raw.length > MAX_PACKET_BYTES) return;
    let packet;
    try { packet = JSON.parse(raw.toString("utf8")); } catch { return; }
    if (["probe", "probe-ack"].includes(packet.type)) {
      establishFromProbe(packet, rinfo);
      return;
    }
    if (packet.type !== DIRECT_RPC_PACKET_TYPE || packet.protocolVersion !== DIRECT_PATH_PROTOCOL_VERSION) return;
    if (packet.toDeviceId !== deviceId || packet.sessionId == null) return;
    const peer = safePeer(peerLookup(String(packet.fromDeviceId || "")));
    if (!peer || peer.generation !== packet.fromGeneration) return;
    const session = sessions.get(peer.deviceId);
    if (!session || session.context.sessionId !== packet.sessionId) return;
    let payload;
    try { payload = session.rpc.open(packet.envelope); } catch { return; }
    session.address = rinfo.address;
    session.port = rinfo.port;
    session.updatedAt = Date.now();
    onPathHealthy({ peerDeviceId: peer.deviceId, address: rinfo.address, port: rinfo.port });
    if (payload.kind === "call") {
      void handleCall(session, payload, rinfo);
      return;
    }
    const waiter = pending.get(payload.invocationId);
    if (!waiter) return;
    pending.delete(payload.invocationId);
    clearTimeout(waiter.timer);
    if (payload.kind === "error" || payload.ok === false) waiter.reject(new Error(String(payload.error || "direct device call failed")));
    else waiter.resolve({ ok: true, result: payload.result, route: "direct-udp", invocationId: payload.invocationId });
  };
  endpoint.socket.on("message", onMessage);

  async function ensureSession(peer, candidate, timeoutMs) {
    const safe = safePeer(peer);
    if (!safe) throw new Error("invalid direct peer");
    const current = sessions.get(safe.deviceId);
    if (current && current.peer.generation === safe.generation) return current;
    await endpoint.probe({ peer: safe, candidate, timeoutMs: Math.min(timeoutMs, 1_500) });
    const established = sessions.get(safe.deviceId);
    if (!established) throw new Error("direct session was not established by authenticated probe");
    return established;
  }

  return Object.freeze({
    async call({ peer, candidate, toolName, arguments: args = {}, invocationId, timeoutMs = DEFAULT_CALL_TIMEOUT_MS }) {
      if (closed) throw new Error("direct RPC transport is closed");
      if (pending.size >= MAX_PENDING_CALLS) throw new Error("too many pending direct RPC calls");
      const id = stableInvocationId(invocationId);
      const session = await ensureSession(peer, candidate, timeoutMs);
      const envelope = session.rpc.seal({ kind: "call", invocationId: id, toolName: String(toolName || "").slice(0, 128), arguments: args });
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          pending.delete(id);
          reject(new Error("direct device call timed out"));
        }, timeoutMs);
        pending.set(id, { resolve, reject, timer });
        sendOuter(session, envelope, candidate.host, candidate.port).catch((error) => {
          pending.delete(id);
          clearTimeout(timer);
          reject(error);
        });
      });
    },
    sessionFor(peerDeviceId) {
      const session = sessions.get(String(peerDeviceId));
      return session ? { sessionId: session.context.sessionId, address: session.address, port: session.port, updatedAt: session.updatedAt } : null;
    },
    close() {
      if (closed) return;
      closed = true;
      endpoint.socket.off("message", onMessage);
      for (const waiter of pending.values()) { clearTimeout(waiter.timer); waiter.reject(new Error("direct RPC transport closed")); }
      pending.clear();
      sessions.clear();
    },
  });
}
