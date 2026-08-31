import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { hostname } from "node:os";
import { WebSocketServer } from "ws";
import { z } from "zod";
import {
  canonicalMeshJson, // GBF-412 canonical gateway catalog
  mergeMeshHeartbeat,
  publicMeshState,
  verifyAndNormalizeMeshRegistration,
} from "./device-mesh.js"; // GBF-412 mesh gateway
import { createDirectPathRegistry } from "./device-direct-path.js"; // GBF-412 direct rendezvous

const DEFAULT_AGENT_PATH = "/agent";
const DEFAULT_CALL_TIMEOUT_SECONDS = 120;
const MAX_CALL_TIMEOUT_SECONDS = 600;
const MAX_ARGUMENTS_JSON_CHARS = 20 * 1024 * 1024;
const MAX_RESULT_BYTES = 32 * 1024 * 1024;
const STALE_AFTER_MS = 70_000;
const DEFAULT_DEVICE_LEASE_SECONDS = 2 * 60 * 60;
const MIN_DEVICE_LEASE_SECONDS = 30;
const MAX_DEVICE_LEASE_SECONDS = 4 * 60 * 60;
const MAX_TOOL_DESCRIPTOR_BYTES = 64 * 1024;
const MAX_TOOL_CATALOG_BYTES = 512 * 1024;
const MAX_METADATA_BYTES = 8 * 1024;
const MAX_DEVICES_PER_ACCOUNT = 50;
const MAX_TOTAL_DEVICES = 500;
const MAX_PENDING_CALLS_PER_DEVICE = 16;
const MAX_PENDING_CALLS_TOTAL = 256;

const devices = new Map();
const pendingCalls = new Map();
const attachedServers = new WeakSet();

function safeEqual(left, right) {
  const a = Buffer.from(String(left));
  const b = Buffer.from(String(right));
  return a.length === b.length && timingSafeEqual(a, b);
}

function bearerToken(req) {
  const header = String(req.headers.authorization ?? "");
  return header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : "";
}

function registryKey(accountId, deviceId) {
  return `${accountId}\0${deviceId}`;
}

function publicToolDescriptor(tool) {
  const name = String(tool?.name ?? "");
  if (!/^[a-zA-Z0-9._-]{1,128}$/u.test(name) || name === "secure_input_submit") return null;
  const descriptor = {
    name,
    ...(tool.title ? { title: String(tool.title).slice(0, 300) } : {}),
    ...(tool.description ? { description: String(tool.description).slice(0, 12_000) } : {}),
    ...(tool.inputSchema && typeof tool.inputSchema === "object" ? { inputSchema: tool.inputSchema } : {}),
    ...(tool.outputSchema && typeof tool.outputSchema === "object" ? { outputSchema: tool.outputSchema } : {}),
    ...(tool.annotations && typeof tool.annotations === "object" ? { annotations: tool.annotations } : {}),
  };
  return Buffer.byteLength(JSON.stringify(descriptor)) <= MAX_TOOL_DESCRIPTOR_BYTES ? descriptor : null;
}

function normalizeToolCatalog(tools, capabilities) {
  const allowed = new Set((Array.isArray(capabilities) ? capabilities : []).map(String));
  const result = [];
  let totalBytes = 0;
  for (const raw of Array.isArray(tools) ? tools.slice(0, 100) : []) {
    const descriptor = publicToolDescriptor(raw);
    if (!descriptor || !allowed.has(descriptor.name)) continue;
    const bytes = Buffer.byteLength(JSON.stringify(descriptor));
    if (totalBytes + bytes > MAX_TOOL_CATALOG_BYTES) break;
    totalBytes += bytes;
    result.push(descriptor);
  }
  return result;
}

function toolCatalogVersion(tools) {
  return tools.length ? createHash("sha256").update(canonicalMeshJson(tools)).digest("hex") : ""; // GBF-412 canonical gateway schema hash
}

function safeSecureInputPublicKey(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const key = {
    kty: String(value.kty || ""),
    crv: String(value.crv || ""),
    x: String(value.x || ""),
    y: String(value.y || ""),
  };
  if (key.kty !== "EC" || key.crv !== "P-256") return null;
  if (![key.x, key.y].every((part) => /^[A-Za-z0-9_-]{40,128}$/u.test(part))) return null;
  return key;
}

function safeMetadata(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const allowed = ["kind", "repository", "workflow", "job", "runId", "runAttempt", "sha", "runnerName", "runnerOs", "runnerArch"];
  const output = {};
  for (const key of allowed) {
    const text = String(value[key] ?? "").trim();
    if (text) output[key] = text.slice(0, 300);
  }
  return Buffer.byteLength(JSON.stringify(output)) <= MAX_METADATA_BYTES ? output : {};
}

function publicDevice(device) {
  return {
    id: device.id,
    name: device.name,
    platform: device.platform,
    status: device.status,
    lastSeen: new Date(device.lastSeen).toISOString(),
    expiresAt: device.central ? null : new Date(device.expiresAt).toISOString(),
    capabilities: device.capabilities,
    toolSchemaCount: Array.isArray(device.tools) ? device.tools.length : 0,
    toolSchemaVersion: device.toolSchemaVersion || "",
    metadata: device.metadata,
    secureInputPublicKey: device.secureInputPublicKey,
    mesh: publicMeshState(device.mesh), // GBF-412 public mesh state
  };
}

function rejectPendingForSocket(socket, reason) {
  for (const [requestId, pending] of pendingCalls) {
    if (pending.socket !== socket) continue;
    pendingCalls.delete(requestId);
    clearTimeout(pending.timer);
    pending.reject(new Error(reason));
  }
}

function markDisconnected(socket) {
  rejectPendingForSocket(socket, `Device ${socket.deviceId || "unknown"} disconnected before the call completed.`);
  if (!socket.registryKey) return;
  const device = devices.get(socket.registryKey);
  if (!device || device.socket !== socket) return;
  device.status = "offline";
  device.socket = null;
  device.lastSeen = Date.now();
}

function rejectSocket(socket, code, reason) {
  try {
    socket.close(code, reason);
  } catch {
    socket.terminate();
  }
}

function rejectUpgrade(socket, status = 401, reason = "Unauthorized") {
  try {
    socket.write(`HTTP/1.1 ${status} ${reason}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
  } finally {
    socket.destroy();
  }
}

function publishDirectPeerMaps(accountId, directPaths) {
  if (!directPaths || !accountId) return;
  for (const device of devices.values()) {
    if (device.accountId !== accountId || device.central || device.status !== "online" || !device.socket || device.socket.readyState !== 1) continue;
    try {
      device.socket.send(JSON.stringify({
        type: "direct_peer_map",
        version: "fabushi.direct-path.v1",
        accountBinding: createHash("sha256").update(String(accountId)).digest("base64url").slice(0, 32), // GBF-412 account-bound direct session
        peers: directPaths.peers(accountId, device.id),
      }));
    } catch {}
  }
} // GBF-412 same-account direct peer map

function audit(options, record) {
  try {
    options.audit?.({ at: new Date().toISOString(), ...record });
  } catch {
    // Auditing must never break the control channel.
  }
}

async function handleAgentMessage(socket, raw, options) { // GBF-412 serialized async identity authorization
  let message;
  try {
    message = JSON.parse(raw.toString("utf8"));
  } catch {
    rejectSocket(socket, 1007, "invalid JSON");
    return;
  }

  if (message.type === "register") {
    const id = String(message.deviceId ?? "").trim();
    const name = String(message.name ?? id).trim();
    const platform = String(message.platform ?? "unknown").trim().slice(0, 80);
    const capabilities = Array.isArray(message.capabilities)
      ? [...new Set(message.capabilities.map(String))].slice(0, 100)
      : [];
    if (!/^[a-zA-Z0-9._:-]{1,128}$/u.test(id) || !name || name.length > 200 || !socket.accountId) {
      rejectSocket(socket, 1008, "invalid device registration");
      return;
    }

    const tools = normalizeToolCatalog(message.tools, capabilities);
    const toolSchemaVersion = toolCatalogVersion(tools);
    const generation = String(message.generation ?? "").trim();
    if (message.mesh != null && !/^[A-Za-z0-9_-]{16,128}$/u.test(generation)) {
      rejectSocket(socket, 1008, "signed mesh registration requires a valid generation");
      return;
    }
    let mesh = null;
    try {
      mesh = verifyAndNormalizeMeshRegistration(message.mesh, {
        deviceId: id,
        generation,
        toolSchemaVersion,
      });
    } catch (error) {
      audit(options, { type: "device.mesh_rejected", accountId: socket.accountId, deviceId: id, error: error instanceof Error ? error.message : String(error) });
      rejectSocket(socket, 1008, "invalid signed mesh registration");
      return;
    }
    if (options.requireSignedMesh === true && !mesh) {
      rejectSocket(socket, 1008, "signed mesh registration required");
      return;
    } // GBF-412 signed mesh verification
    const meshMetadata = safeMetadata(message.metadata);
    if (mesh) {
      if (typeof options.authorizeMeshIdentity === "function") {
        let authorization;
        try {
          authorization = await options.authorizeMeshIdentity({
            accountId: socket.accountId,
            deviceId: id,
            nodeKeyFingerprint: mesh.nodeKeyFingerprint,
            platform,
            name,
            metadata: meshMetadata,
          });
        } catch (error) {
          audit(options, { type: "device.identity_authorization_failed", accountId: socket.accountId, deviceId: id, error: error instanceof Error ? error.message : String(error) });
          rejectSocket(socket, 1011, "device identity authorization failed");
          return;
        }
        if (!authorization?.accepted) {
          audit(options, {
            type: "device.identity_rejected",
            accountId: socket.accountId,
            deviceId: id,
            nodeKeyFingerprint: mesh.nodeKeyFingerprint,
            code: String(authorization?.code || "device_identity_rejected").slice(0, 120),
          });
          rejectSocket(socket, 1008, "device identity approval required");
          return;
        }
        const identityStatus = String(authorization.status || "verified");
        mesh.identityStatus = ["enrolled", "verified", "rotated"].includes(identityStatus) ? identityStatus : "verified";
        mesh.identityBindingVersion = Number.isSafeInteger(authorization.bindingVersion) ? authorization.bindingVersion : 1;
      } else if (options.requirePinnedMesh === true) {
        rejectSocket(socket, 1011, "device identity registry unavailable");
        return;
      }
    } // GBF-412 persistent node identity authorization
    const leaseSeconds = Math.min(
      Math.max(Number(message.leaseSeconds) || Number(options.defaultLeaseSeconds) || DEFAULT_DEVICE_LEASE_SECONDS, MIN_DEVICE_LEASE_SECONDS),
      Number(options.maxLeaseSeconds) || MAX_DEVICE_LEASE_SECONDS,
    );
    const now = Date.now();
    const expiresAt = now + leaseSeconds * 1000;
    const key = registryKey(socket.accountId, id);
    const previous = devices.get(key);
    if (!previous) {
      const accountDeviceCount = [...devices.values()].filter((device) => device.accountId === socket.accountId).length;
      if (accountDeviceCount >= MAX_DEVICES_PER_ACCOUNT || devices.size >= MAX_TOTAL_DEVICES) {
        rejectSocket(socket, 1013, "device registry capacity reached");
        return;
      }
    }
    if (previous?.socket && previous.socket !== socket) {
      rejectPendingForSocket(previous.socket, `Device ${id} reconnected before the call completed.`);
      rejectSocket(previous.socket, 4001, "device reconnected");
    }
    const metadata = meshMetadata; // GBF-412 reuse identity-authorized metadata
    const secureInputPublicKey = safeSecureInputPublicKey(message.secureInputPublicKey);
    devices.set(key, {
      accountId: socket.accountId,
      id,
      name,
      platform,
      capabilities,
      tools,
      toolSchemaVersion,
      generation,
      mesh, // GBF-412 stored node/path state
      metadata,
      secureInputPublicKey,
      status: "online",
      lastSeen: now,
      expiresAt,
      socket,
    });
    socket.deviceId = id;
    socket.registryKey = key;
    if (mesh && options.directPaths) {
      const direct = options.directPaths.update({
        accountId: socket.accountId,
        deviceId: id,
        generation,
        nodeKeyFingerprint: mesh.nodeKeyFingerprint,
        candidates: message.direct?.candidates,
        leaseExpiresAt: expiresAt,
      });
      if (direct.candidates.length) {
        mesh.supportedPaths = [...new Set(["direct-udp", ...mesh.supportedPaths])];
        mesh.preferredPath = "direct-udp";
      }
    } // GBF-412 direct candidate enrollment
    socket.send(JSON.stringify({
      type: "registered",
      deviceId: id,
      expiresAt: new Date(expiresAt).toISOString(),
      mesh: publicMeshState(mesh),
      ...(options.directPaths ? { directPeers: options.directPaths.peers(socket.accountId, id) } : {}),
    }));
    publishDirectPeerMaps(socket.accountId, options.directPaths); // GBF-412 publish rendezvous after register
    audit(options, {
      type: "device.registered",
      accountId: socket.accountId,
      deviceId: id,
      metadata,
      mesh: { signed: Boolean(mesh), nodeKeyFingerprint: mesh?.nodeKeyFingerprint || "", activePath: mesh?.activePath || "relay" },
    }); // GBF-412 registration response and audit
    return;
  }

  if (message.type === "heartbeat") {
    const device = devices.get(socket.registryKey);
    if (device && device.socket === socket) {
      device.lastSeen = Date.now();
      device.mesh = mergeMeshHeartbeat(device.mesh, message.mesh); // GBF-412 heartbeat posture/path
      if (device.mesh && options.directPaths && message.direct?.candidates) {
        const direct = options.directPaths.update({
          accountId: socket.accountId,
          deviceId: device.id,
          generation: device.generation,
          nodeKeyFingerprint: device.mesh.nodeKeyFingerprint,
          candidates: message.direct.candidates,
          leaseExpiresAt: device.expiresAt,
        });
        if (direct.candidates.length) {
          device.mesh.supportedPaths = [...new Set(["direct-udp", ...device.mesh.supportedPaths])];
          device.mesh.preferredPath = "direct-udp";
        }
        publishDirectPeerMaps(socket.accountId, options.directPaths);
      } // GBF-412 refresh direct candidates
      device.status = device.expiresAt > Date.now() ? "online" : "offline";
      if (device.status === "offline") rejectSocket(socket, 4003, "device lease expired");
    }
    return;
  }

  if (message.type === "direct_path_health") {
    if (!options.directPaths || !socket.registryKey) return;
    const reporter = devices.get(socket.registryKey);
    const targetId = String(message.targetDeviceId || "").trim();
    const target = devices.get(registryKey(socket.accountId, targetId));
    if (!reporter || reporter.socket !== socket || !target || target.central || !target.mesh) return;
    const accepted = options.directPaths.reportHealth({
      accountId: socket.accountId,
      deviceId: target.id,
      generation: target.generation,
      candidateId: String(message.candidateId || ""),
      reachable: message.reachable === true,
      latencyMs: Number(message.latencyMs) || 0,
      loss: Number(message.loss) || 0,
    });
    if (!accepted) return;
    if (message.reachable === true) target.directRouterId = reporter.id;
    else if (target.directRouterId === reporter.id) target.directRouterId = null; // GBF-412 remember authenticated direct reporter
    const selected = options.directPaths.select(socket.accountId, target.id);
    const nextPath = selected.path === "direct-udp" ? "direct-udp" : "relay";
    if (target.mesh.activePath !== nextPath) target.mesh.pathChangedAt = Date.now();
    target.mesh.activePath = nextPath;
    publishDirectPeerMaps(socket.accountId, options.directPaths);
    audit(options, { type: "device.direct_path_health", accountId: socket.accountId, reporterDeviceId: reporter.id, targetDeviceId: target.id, activePath: nextPath, latencyMs: Number(message.latencyMs) || 0 });
    return;
  } // GBF-412 authenticated direct path health

  if (message.type === "direct_forward_failed") {
    const requestId = String(message.requestId ?? "");
    const pending = pendingCalls.get(requestId);
    if (!pending || pending.socket !== socket || pending.route !== "direct-udp") return;
    if (String(message.invocationId || "") !== pending.invocationId) return;
    const target = devices.get(pending.targetRegistryKey);
    if (!target || target.status !== "online" || !target.socket || target.socket.readyState !== 1) {
      pendingCalls.delete(requestId);
      clearTimeout(pending.timer);
      pending.reject(new Error(`Device ${pending.targetDeviceId} became unavailable during direct fallback.`));
      return;
    }
    pending.socket = target.socket;
    pending.registryKey = pending.targetRegistryKey;
    pending.route = "relay";
    target.socket.send(JSON.stringify({ type: "call", requestId, invocationId: pending.invocationId, toolName: pending.toolName, arguments: pending.arguments }), (error) => {
      if (!error) return;
      if (pendingCalls.get(requestId) !== pending) return;
      pendingCalls.delete(requestId);
      clearTimeout(pending.timer);
      pending.reject(error);
    });
    audit(options, { type: "device.direct_fallback", accountId: socket.accountId, routerDeviceId: socket.deviceId || "", targetDeviceId: pending.targetDeviceId, invocationId: pending.invocationId, reason: String(message.error || "direct forwarding failed").slice(0, 300) });
    return;
  } // GBF-412 direct to relay fallback with same invocation

  if (message.type === "result") {
    const requestId = String(message.requestId ?? "");
    const pending = pendingCalls.get(requestId);
    if (!pending || pending.registryKey !== socket.registryKey || pending.socket !== socket) return;
    if (message.invocationId && String(message.invocationId) !== pending.invocationId) return; // GBF-412 bind result to invocation
    pendingCalls.delete(requestId);
    clearTimeout(pending.timer);
    message.route = message.route === "direct-udp" ? "direct-udp" : pending.route || "relay"; // GBF-412 route observability
    pending.resolve(message);
  }
}

export function attachDeviceGateway(httpServer, options = {}) {
  if (attachedServers.has(httpServer)) return null;
  const path = options.path ?? process.env.DEVICE_GATEWAY_PATH ?? DEFAULT_AGENT_PATH;
  const resolveAccount = options.resolveAccount;
  const legacyToken = String(options.token ?? process.env.DEVICE_GATEWAY_TOKEN ?? "");
  const legacyAccountId = String(options.legacyAccountId ?? process.env.DEVICE_GATEWAY_LEGACY_ACCOUNT_ID ?? "legacy");
  if (typeof resolveAccount !== "function" && legacyToken.length < 32) return null;
  attachedServers.add(httpServer);

  const centralId = options.centralId ?? process.env.DEVICE_CENTRAL_ID ?? hostname();
  if (options.centralAccountId && Array.isArray(options.centralCapabilities)) {
    const centralTools = normalizeToolCatalog(options.centralTools, options.centralCapabilities);
    devices.set(registryKey(options.centralAccountId, centralId), {
      accountId: options.centralAccountId,
      id: centralId,
      name: options.centralName ?? process.env.DEVICE_CENTRAL_NAME ?? centralId,
      platform: process.platform,
      capabilities: options.centralCapabilities,
      tools: centralTools,
      toolSchemaVersion: toolCatalogVersion(centralTools),
      generation: "central",
      mesh: null, // GBF-412 central mesh compatibility
      metadata: { kind: "central" },
      secureInputPublicKey: null,
      status: "online",
      lastSeen: Date.now(),
      expiresAt: Number.MAX_SAFE_INTEGER,
      socket: null,
      central: true,
    });
  }

  const directPaths = options.directPaths ?? createDirectPathRegistry(); // GBF-412 direct path coordinator
  const gatewayOptions = { ...options, directPaths };
  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_RESULT_BYTES });
  const onUpgrade = async (req, socket, head) => {
    let pathname = "";
    try {
      pathname = new URL(req.url ?? "", "http://localhost").pathname;
    } catch {
      socket.destroy();
      return;
    }
    if (pathname !== path) return;
    const token = bearerToken(req);
    try {
      let account;
      if (typeof resolveAccount === "function") account = await resolveAccount(token, req);
      else if (legacyToken.length >= 32 && safeEqual(token, legacyToken)) account = { userId: legacyAccountId };
      if (!account?.userId) return rejectUpgrade(socket);
      req.fabushiAccount = account;
      wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws, req));
    } catch {
      rejectUpgrade(socket);
    }
  };
  httpServer.on("upgrade", onUpgrade);

  wss.on("connection", (socket, req) => {
    socket.accountId = String(req.fabushiAccount?.userId || "");
    socket.isAlive = true;
    socket.messageChain = Promise.resolve(); // GBF-412 serialize registration and calls
    socket.on("pong", () => {
      socket.isAlive = true;
      const device = devices.get(socket.registryKey);
      if (device && device.socket === socket) device.lastSeen = Date.now();
    });
    socket.on("message", (raw) => {
      socket.messageChain = socket.messageChain
        .then(() => handleAgentMessage(socket, raw, gatewayOptions)) // GBF-412 direct-aware message handling
        .catch((error) => {
          audit(options, { type: "device.message_failed", accountId: socket.accountId, deviceId: socket.deviceId || "", error: error instanceof Error ? error.message : String(error) });
          rejectSocket(socket, 1011, "device message handling failed");
        });
    }); // GBF-412 serialized device message queue
    socket.on("close", () => {
      audit(options, { type: "device.disconnected", accountId: socket.accountId, deviceId: socket.deviceId || "" });
      markDisconnected(socket);
    });
    socket.on("error", () => markDisconnected(socket));
  });

  const heartbeatTimer = setInterval(() => {
    const now = Date.now();
    for (const socket of wss.clients) {
      if (!socket.isAlive) {
        socket.terminate();
        continue;
      }
      socket.isAlive = false;
      socket.ping();
    }
    for (const device of devices.values()) {
      if (device.central) continue;
      if (now - device.lastSeen > STALE_AFTER_MS || device.expiresAt <= now) {
        device.status = "offline";
        if (device.socket && device.expiresAt <= now) rejectSocket(device.socket, 4003, "device lease expired");
      }
      if (!device.socket && device.expiresAt + 5 * 60_000 <= now) devices.delete(registryKey(device.accountId, device.id));
    }
  }, 25_000);
  heartbeatTimer.unref();

  return {
    path,
    close: async () => {
      clearInterval(heartbeatTimer);
      httpServer.off("upgrade", onUpgrade);
      for (const socket of wss.clients) socket.close(1001, "gateway closing");
      await new Promise((resolve) => wss.close(resolve));
    },
  };
}

export function disconnectRegisteredDevice(accountId, deviceId, reason = "device identity trust changed") {
  const key = registryKey(String(accountId || "").trim(), String(deviceId || "").trim());
  const device = devices.get(key);
  if (!device || device.central) return false;
  const socket = device.socket;
  device.status = "offline";
  device.socket = null;
  device.lastSeen = Date.now();
  if (socket) {
    rejectPendingForSocket(socket, `Device ${device.id} identity trust changed before the call completed.`);
    rejectSocket(socket, 4004, String(reason || "device identity trust changed").slice(0, 120));
  }
  return true;
} // GBF-412 identity rotation disconnect

export function listRegisteredDevices(accountId) {
  const normalizedAccountId = String(accountId || "").trim();
  if (!normalizedAccountId) return [];
  const now = Date.now();
  return [...devices.values()]
    .filter((device) => device.accountId === normalizedAccountId)
    .map((device) => {
      if (!device.central && (device.expiresAt <= now || now - device.lastSeen > STALE_AFTER_MS)) device.status = "offline";
      return publicDevice(device);
    })
    .sort((a, b) => a.id.localeCompare(b.id));
}

export function describeRegisteredDeviceTool(accountId, deviceId, toolName) {
  const device = devices.get(registryKey(accountId, deviceId));
  if (!device) throw new Error(`Unknown device: ${deviceId}. Call list_devices first.`);
  const tool = Array.isArray(device.tools) ? device.tools.find((entry) => entry.name === toolName) ?? null : null;
  return {
    deviceId,
    toolName,
    available: Boolean(tool),
    schemaVersion: device.toolSchemaVersion || "",
    tool,
    message: tool
      ? `Returned the current schema for ${toolName} on ${deviceId}.`
      : `No schema is registered for ${toolName} on ${deviceId}.`,
  };
}

export async function callRegisteredDevice(accountId, deviceId, toolName, args, timeoutSeconds = DEFAULT_CALL_TIMEOUT_SECONDS) {
  const key = registryKey(accountId, deviceId);
  const device = devices.get(key);
  if (!device) throw new Error(`Unknown device: ${deviceId}. Call list_devices first.`);
  if (device.central) throw new Error(`Device ${deviceId} is the central server; use its existing MCP tools directly.`);
  if (device.expiresAt <= Date.now()) throw new Error(`Device ${deviceId} lease has expired.`);
  if (device.status !== "online" || !device.socket || device.socket.readyState !== 1) throw new Error(`Device ${deviceId} is offline.`);
  if (!device.capabilities.includes(toolName)) throw new Error(`Device ${deviceId} does not expose tool ${toolName}.`);

  const pendingForDevice = [...pendingCalls.values()].filter((pending) => (pending.targetRegistryKey || pending.registryKey) === key).length; // GBF-412 count forwarded calls against target
  if (pendingCalls.size >= MAX_PENDING_CALLS_TOTAL || pendingForDevice >= MAX_PENDING_CALLS_PER_DEVICE) {
    throw new Error(`Device ${deviceId} already has too many pending calls.`);
  }
  const invocationId = randomBytes(16).toString("hex"); // GBF-412 transport-independent invocation id
  const requestId = randomBytes(16).toString("hex");
  const timeoutMs = Math.min(Math.max(Number(timeoutSeconds) || DEFAULT_CALL_TIMEOUT_SECONDS, 1), MAX_CALL_TIMEOUT_SECONDS) * 1000;
  const routerKey = device.directRouterId ? registryKey(accountId, device.directRouterId) : "";
  const router = routerKey ? devices.get(routerKey) : null;
  const useDirect = device.mesh?.activePath === "direct-udp"
    && router && router.id !== device.id && router.status === "online" && router.socket?.readyState === 1; // GBF-412 choose healthy peer router
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pendingCalls.delete(requestId);
      reject(new Error(`Device call timed out after ${timeoutMs / 1000} seconds.`));
    }, timeoutMs);
    const responseSocket = useDirect ? router.socket : device.socket;
    const responseRegistryKey = useDirect ? routerKey : key;
    const pending = {
      registryKey: responseRegistryKey, targetRegistryKey: key, targetDeviceId: deviceId,
      socket: responseSocket, invocationId, toolName, arguments: args,
      route: useDirect ? "direct-udp" : "relay", resolve, reject, timer,
    };
    pendingCalls.set(requestId, pending);
    const outbound = useDirect
      ? { type: "direct_forward_call", requestId, invocationId, targetDeviceId: deviceId, targetGeneration: device.generation, toolName, arguments: args, timeoutMs: Math.min(timeoutMs, 5_000) }
      : { type: "call", requestId, invocationId, toolName, arguments: args };
    responseSocket.send(JSON.stringify(outbound), (error) => { // GBF-412 direct-first dispatch
      if (!error) return;
      pendingCalls.delete(requestId);
      clearTimeout(timer);
      reject(error);
    });
  });
}

export function resetDeviceGatewayStateForTests() {
  for (const pending of pendingCalls.values()) clearTimeout(pending.timer);
  pendingCalls.clear();
  devices.clear();
}

const meshShape = z.object({
  protocolVersion: z.string().nullable(),
  nodeKeyFingerprint: z.string().optional(),
  signed: z.boolean(),
  identityStatus: z.enum(["legacy", "self-signed", "enrolled", "verified", "rotated"]),
  identityBindingVersion: z.number().int().positive().nullable(), // GBF-412 mesh identity schema
  supportedPaths: z.array(z.string()),
  preferredPath: z.string(),
  activePath: z.string(),
  features: z.array(z.string()),
  tags: z.array(z.string()),
  posture: z.record(z.string(), z.string()),
  pathChangedAt: z.string().optional(),
}); // GBF-412 mesh output schema

const deviceShape = z.object({
  id: z.string(),
  name: z.string(),
  platform: z.string(),
  status: z.enum(["online", "offline"]),
  lastSeen: z.string(),
  expiresAt: z.string().nullable(),
  metadata: z.record(z.string(), z.string()),
  secureInputPublicKey: z.object({ kty: z.literal("EC"), crv: z.literal("P-256"), x: z.string(), y: z.string() }).nullable(),
  mesh: meshShape, // GBF-412 mesh device shape
  capabilities: z.array(z.string()),
  toolSchemaCount: z.number().int().nonnegative(),
  toolSchemaVersion: z.string(),
});

const toolDescriptorShape = z.object({
  name: z.string(),
  title: z.string().optional(),
  description: z.string().optional(),
  inputSchema: z.unknown().optional(),
  outputSchema: z.unknown().optional(),
  annotations: z.unknown().optional(),
});

const describeDeviceToolShape = {
  deviceId: z.string(),
  toolName: z.string(),
  available: z.boolean(),
  schemaVersion: z.string(),
  tool: toolDescriptorShape.nullable(),
  message: z.string(),
};

export const deviceToolOutputShape = {
  deviceId: z.string(),
  toolName: z.string(),
  status: z.enum(["completed", "failed"]),
  route: z.enum(["direct-udp", "relay"]).optional(), // GBF-412 device call route output
  resultJson: z.string(),
};

export function registerDeviceTools(server, options = {}) {
  const canRead = options.canRead ?? (() => true);
  const canWrite = options.canWrite ?? (() => true);
  const readAuthError = options.readAuthError ?? (() => ({ isError: true, content: [{ type: "text", text: "Read authorization required." }] }));
  const writeAuthError = options.writeAuthError ?? (() => ({ isError: true, content: [{ type: "text", text: "Write authorization required." }] }));
  const readSecuritySchemes = options.readSecuritySchemes ?? [{ type: "noauth" }];
  const writeSecuritySchemes = options.writeSecuritySchemes ?? [{ type: "oauth2", scopes: ["vps.write"] }];
  const accountId = options.accountId ?? (() => "");
  const requiredAccountId = () => String(typeof accountId === "function" ? accountId() : accountId || "").trim();

  server.registerTool(
    "list_devices",
    {
      title: "List controllable devices",
      description: "Return only the live computers registered to the authenticated Fabushi account. Call this before selecting a device.",
      inputSchema: {},
      outputSchema: { devices: z.array(deviceShape) },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: true, idempotentHint: true },
      securitySchemes: readSecuritySchemes,
    },
    async () => {
      if (!canRead()) return readAuthError();
      const accountId = requiredAccountId();
      if (!accountId) return readAuthError();
      const result = { devices: listRegisteredDevices(accountId) };
      return { structuredContent: result, content: [{ type: "text", text: JSON.stringify(result) }] };
    }
  );

  server.registerTool(
    "describe_device_tool",
    {
      title: "Describe a device tool",
      description: "Return the latest MCP title, description, input schema, output schema, and annotations for one tool advertised by a selected device.",
      inputSchema: { deviceId: z.string().min(1).max(128), toolName: z.string().min(1).max(128) },
      outputSchema: describeDeviceToolShape,
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: true, idempotentHint: true },
      securitySchemes: readSecuritySchemes,
    },
    async ({ deviceId, toolName }) => {
      if (!canRead()) return readAuthError();
      const accountId = requiredAccountId();
      if (!accountId) return readAuthError();
      const result = describeRegisteredDeviceTool(accountId, deviceId, toolName);
      return { structuredContent: result, content: [{ type: "text", text: result.message }] };
    }
  );

  server.registerTool(
    "device_call",
    {
      title: "Call a tool on a device",
      description: "Call one advertised MCP tool on a dynamically connected device. Obtain deviceId and toolName from list_devices; use describe_device_tool when the schema is unfamiliar or may have changed; argumentsJson must be a JSON object.",
      inputSchema: {
        deviceId: z.string().min(1).max(128),
        toolName: z.string().min(1).max(128),
        argumentsJson: z.string().max(MAX_ARGUMENTS_JSON_CHARS).default("{}"),
        timeoutSeconds: z.number().int().min(1).max(MAX_CALL_TIMEOUT_SECONDS).optional(),
      },
      outputSchema: deviceToolOutputShape,
      annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: true },
      securitySchemes: writeSecuritySchemes,
    },
    async ({ deviceId, toolName, argumentsJson, timeoutSeconds }) => {
      if (!canWrite()) return writeAuthError();
      let args;
      try {
        args = JSON.parse(argumentsJson || "{}");
        if (!args || Array.isArray(args) || typeof args !== "object") throw new Error("not an object");
      } catch (error) {
        const result = { deviceId, toolName, status: "failed", resultJson: JSON.stringify({ error: `Invalid argumentsJson: ${error.message}` }) };
        return { isError: true, structuredContent: result, content: [{ type: "text", text: result.resultJson }] };
      }

      try {
        const accountId = requiredAccountId();
        if (!accountId) return writeAuthError();
        const response = await callRegisteredDevice(accountId, deviceId, toolName, args, timeoutSeconds);
        const result = {
          deviceId,
          toolName,
          status: response.ok === false ? "failed" : "completed",
          route: response.route === "direct-udp" ? "direct-udp" : "relay", // GBF-412 expose selected route
          resultJson: JSON.stringify(response.result?.structuredContent ?? response.result ?? { error: response.error }),
        };
        const content = Array.isArray(response.result?.content) ? response.result.content : [{ type: "text", text: result.resultJson }];
        return { isError: response.ok === false, structuredContent: result, content };
      } catch (error) {
        const result = { deviceId, toolName, status: "failed", resultJson: JSON.stringify({ error: error instanceof Error ? error.message : String(error) }) };
        return { isError: true, structuredContent: result, content: [{ type: "text", text: result.resultJson }] };
      }
    }
  );
}

export function buildDeviceToolDescriptors(options = {}) {
  const readSecuritySchemes = options.readSecuritySchemes ?? [{ type: "noauth" }];
  const writeSecuritySchemes = options.writeSecuritySchemes ?? [{ type: "oauth2", scopes: ["vps.write"] }];
  return [
    {
      name: "list_devices",
      title: "List controllable devices",
      description: "Return only the live computers registered to the authenticated Fabushi account. Call this before selecting a device.",
      inputSchema: { type: "object", properties: {}, additionalProperties: false },
      outputSchema: {
        type: "object",
        properties: {
          devices: {
            type: "array",
            items: {
              type: "object",
              properties: {
                id: { type: "string" }, name: { type: "string" }, platform: { type: "string" },
                status: { type: "string", enum: ["online", "offline"] }, lastSeen: { type: "string" },
                expiresAt: { type: ["string", "null"] }, metadata: { type: "object", additionalProperties: { type: "string" } },
                secureInputPublicKey: { anyOf: [{ type: "object", required: ["kty", "crv", "x", "y"], properties: { kty: { const: "EC" }, crv: { const: "P-256" }, x: { type: "string" }, y: { type: "string" } }, additionalProperties: false }, { type: "null" }] },
                mesh: { type: "object", required: ["protocolVersion", "signed", "identityStatus", "identityBindingVersion", "supportedPaths", "preferredPath", "activePath", "features", "tags", "posture"], properties: { protocolVersion: { type: ["string", "null"] }, nodeKeyFingerprint: { type: "string" }, signed: { type: "boolean" }, identityStatus: { type: "string", enum: ["legacy", "self-signed", "enrolled", "verified", "rotated"] }, identityBindingVersion: { type: ["integer", "null"], minimum: 1 }, supportedPaths: { type: "array", items: { type: "string" } }, preferredPath: { type: "string" }, activePath: { type: "string" }, features: { type: "array", items: { type: "string" } }, tags: { type: "array", items: { type: "string" } }, posture: { type: "object", additionalProperties: { type: "string" } }, pathChangedAt: { type: "string" } }, additionalProperties: false }, // GBF-412 pinned mesh JSON schema
                capabilities: { type: "array", items: { type: "string" } },
                toolSchemaCount: { type: "integer", minimum: 0 }, toolSchemaVersion: { type: "string" },
              },
              required: ["id", "name", "platform", "status", "lastSeen", "expiresAt", "metadata", "secureInputPublicKey", "mesh", "capabilities", "toolSchemaCount", "toolSchemaVersion"], // GBF-412 mesh required
              additionalProperties: false,
            },
          },
        },
        required: ["devices"],
        additionalProperties: false,
      },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: true, idempotentHint: true },
      securitySchemes: readSecuritySchemes,
    },
    {
      name: "describe_device_tool",
      title: "Describe a device tool",
      description: "Return the latest MCP title, description, input schema, output schema, and annotations for one tool advertised by a selected device.",
      inputSchema: {
        type: "object",
        properties: { deviceId: { type: "string", minLength: 1, maxLength: 128 }, toolName: { type: "string", minLength: 1, maxLength: 128 } },
        required: ["deviceId", "toolName"],
        additionalProperties: false,
      },
      outputSchema: {
        type: "object",
        properties: {
          deviceId: { type: "string" }, toolName: { type: "string" }, available: { type: "boolean" }, schemaVersion: { type: "string" },
          tool: { type: ["object", "null"] }, message: { type: "string" },
        },
        required: ["deviceId", "toolName", "available", "schemaVersion", "tool", "message"],
        additionalProperties: false,
      },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: true, idempotentHint: true },
      securitySchemes: readSecuritySchemes,
    },
    {
      name: "device_call",
      title: "Call a tool on a device",
      description: "Call one advertised MCP tool on a dynamically connected device. Obtain deviceId and toolName from list_devices; use describe_device_tool when the schema is unfamiliar or may have changed; argumentsJson must be a JSON object.",
      inputSchema: {
        type: "object",
        properties: {
          deviceId: { type: "string", minLength: 1, maxLength: 128 },
          toolName: { type: "string", minLength: 1, maxLength: 128 },
          argumentsJson: { type: "string", maxLength: MAX_ARGUMENTS_JSON_CHARS, default: "{}" },
          timeoutSeconds: { type: "integer", minimum: 1, maximum: MAX_CALL_TIMEOUT_SECONDS },
        },
        required: ["deviceId", "toolName"],
        additionalProperties: false,
      },
      outputSchema: {
        type: "object",
        properties: {
          deviceId: { type: "string" }, toolName: { type: "string" },
          status: { type: "string", enum: ["completed", "failed"] }, route: { type: "string", enum: ["direct-udp", "relay"] }, resultJson: { type: "string" }, // GBF-412 route JSON schema
        },
        required: ["deviceId", "toolName", "status", "resultJson"],
        additionalProperties: false,
      },
      annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: true },
      securitySchemes: writeSecuritySchemes,
    },
  ];
}
