import { execFileSync } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import { appendFile, mkdir } from "node:fs/promises";
import { hostname, platform } from "node:os";
import { dirname, resolve } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import WebSocket from "ws";
import { createSecureInputChannel, resolveSensitiveTemplate } from "./secure-input.js";
import { createFabushiAccountSessionStore } from "./fabushi-account-session.js";
import {
  buildSignedMeshRegistration,
  canonicalMeshJson, // GBF-412 canonical agent catalog
  defaultMeshIdentityPath,
  loadOrCreateMeshIdentity,
  meshPostureFromEnvironment,
  parseMeshTags,
} from "./device-mesh.js"; // GBF-412 device mesh
import { bindDirectProbeEndpoint, collectHostUdpCandidates, discoverServerReflexiveCandidate } from "./device-direct-path.js"; // GBF-412 direct agent
import { createInvocationDeduper } from "./device-direct-rpc.js"; // GBF-412 direct RPC dedupe
import { attachDirectRpcTransport } from "./device-direct-transport.js"; // GBF-412 encrypted peer RPC transport

const HEARTBEAT_MS = 20_000;
const MAX_RECONNECT_MS = 30_000;
const MAX_TOOL_DESCRIPTOR_BYTES = 64 * 1024;
const MAX_TOOL_CATALOG_BYTES = 512 * 1024;
const REGISTRATION_TIMEOUT_MS = 15_000;
const MIN_LEASE_SECONDS = 30;
const MAX_LEASE_SECONDS = 4 * 60 * 60;

function publicToolDescriptor(tool) {
  const name = String(tool?.name || "");
  if (!/^[a-zA-Z0-9._-]{1,128}$/u.test(name) || name === "secure_input_submit") return null;
  const descriptor = {
    name,
    ...(tool.title ? { title: String(tool.title).slice(0, 300) } : {}),
    ...(tool.description ? { description: String(tool.description).slice(0, 12_000) } : {}),
    ...(tool.inputSchema && typeof tool.inputSchema === "object" ? { inputSchema: tool.inputSchema } : {}),
    ...(tool.outputSchema && typeof tool.outputSchema === "object" ? { outputSchema: tool.outputSchema } : {}),
    ...(tool.annotations && typeof tool.annotations === "object" ? { annotations: tool.annotations } : {}),
  };
  const encoded = JSON.stringify(descriptor);
  return Buffer.byteLength(encoded) <= MAX_TOOL_DESCRIPTOR_BYTES ? descriptor : null;
}

function buildToolCatalog(tools) {
  const result = [];
  let totalBytes = 0;
  for (const tool of Array.isArray(tools) ? tools : []) {
    const descriptor = publicToolDescriptor(tool);
    if (!descriptor) continue;
    const bytes = Buffer.byteLength(JSON.stringify(descriptor));
    if (totalBytes + bytes > MAX_TOOL_CATALOG_BYTES) break;
    totalBytes += bytes;
    result.push(descriptor);
  }
  return result;
}

function parseJsonArray(value, name) {
  if (!value) return [];
  let parsed;
  try { parsed = JSON.parse(value); } catch { throw new Error(`${name} must be valid JSON.`); }
  if (!Array.isArray(parsed) || parsed.length > 64 || parsed.some((item) => typeof item !== "string" || item.length > 4096)) {
    throw new Error(`${name} must be a JSON string array.`);
  }
  return parsed;
}

function readConfiguredGatewayToken(env) {
  let token = String(env.FABUSHI_ACCOUNT_ACCESS_TOKEN ?? "").trim();
  const tokenFile = String(env.FABUSHI_ACCOUNT_TOKEN_FILE ?? "").trim();
  if (!token && tokenFile) {
    try { token = readFileSync(resolve(tokenFile), "utf8").trim(); }
    catch { throw new Error("Unable to read FABUSHI_ACCOUNT_TOKEN_FILE."); }
  }
  if (!token) token = String(env.DEVICE_GATEWAY_TOKEN ?? "").trim();
  if (platform() === "darwin" && env.DEVICE_GATEWAY_TOKEN_KEYCHAIN_SERVICE) {
    try {
      token = execFileSync("security", [
        "find-generic-password",
        "-s",
        env.DEVICE_GATEWAY_TOKEN_KEYCHAIN_SERVICE,
        "-a",
        env.DEVICE_GATEWAY_TOKEN_KEYCHAIN_ACCOUNT || "device-gateway-token",
        "-w",
      ], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    } catch {
      if (token.length < 24) throw new Error("Unable to read the Fabushi device token from macOS Keychain and no valid fallback token is configured.");
    }
  }
  return token;
}

function safeGatewayUrl(value, env) {
  const url = new URL(String(value || ""));
  if (url.username || url.password || url.search || url.hash) throw new Error("DEVICE_GATEWAY_URL must not contain credentials, query data, or a fragment.");
  const loopback = ["127.0.0.1", "localhost", "::1", "[::1]"].includes(url.hostname.toLowerCase());
  if (url.protocol !== "wss:" && !(url.protocol === "ws:" && (loopback || env.FABUSHI_ALLOW_INSECURE_GATEWAY === "1"))) {
    throw new Error("DEVICE_GATEWAY_URL must use wss:// outside loopback.");
  }
  return url.toString();
}

function runnerMetadata(env) {
  const candidates = {
    kind: env.GITHUB_ACTIONS === "true" ? "github-actions" : (env.DEVICE_KIND || "fabushi-desktop"),
    repository: env.GITHUB_REPOSITORY,
    workflow: env.GITHUB_WORKFLOW,
    job: env.GITHUB_JOB,
    runId: env.GITHUB_RUN_ID,
    runAttempt: env.GITHUB_RUN_ATTEMPT,
    sha: env.GITHUB_SHA,
    runnerName: env.RUNNER_NAME,
    runnerOs: env.RUNNER_OS,
    runnerArch: env.RUNNER_ARCH,
  };
  return Object.fromEntries(Object.entries(candidates)
    .map(([key, value]) => [key, String(value || "").trim().slice(0, 300)])
    .filter(([, value]) => value));
}

function safeChildEnvironment(env, electronNode) {
  const exact = new Set([
    "HOME", "PATH", "TMPDIR", "TEMP", "TMP", "USER", "USERNAME", "LOGNAME", "LANG", "LC_ALL",
    "DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "DBUS_SESSION_BUS_ADDRESS", "NO_AT_BRIDGE", "GTK_MODULES",
    "SystemRoot", "COMSPEC", "PATHEXT", "APPDATA", "LOCALAPPDATA", "USERPROFILE",
    "GITHUB_ACTIONS", "RUNNER_TEMP", "FABUSHI_CI_SESSION_DIR",
  ]);
  const prefixes = ["FABUSHI_COMPUTER_", "FABUSHI_APP_AGENT_", "CHATGPT_COMPUTER_", "COMPUTER_", "MAHAYANA_COMPUTER_MCP_"];
  const child = {};
  for (const [key, value] of Object.entries(env)) {
    if (typeof value !== "string") continue;
    if (exact.has(key) || prefixes.some((prefix) => key.startsWith(prefix))) child[key] = value;
  }
  if (electronNode) child.ELECTRON_RUN_AS_NODE = "1";
  return child;
}


function redactTrace(value, key = "", depth = 0) {
  if (depth > 8) return "<depth-limit>";
  if (/password|passwd|token|secret|authorization|cookie|credential|private|envelope/iu.test(key)) return "<redacted>";
  if (typeof value === "string") return value.length > 4_000 ? `${value.slice(0, 4_000)}<truncated>` : value;
  if (typeof value === "number" || typeof value === "boolean" || value == null) return value;
  if (Array.isArray(value)) return value.slice(0, 100).map((item) => redactTrace(item, key, depth + 1));
  if (typeof value === "object") {
    const output = {};
    for (const [childKey, childValue] of Object.entries(value).slice(0, 200)) output[childKey] = redactTrace(childValue, childKey, depth + 1);
    return output;
  }
  return String(value);
}

const INPUT_BEARING_TOOLS = new Set([
  "fabushi.app.action",
  "computer_app_state",
  "computer_browser_locator",
  "computer_browser_utility",
  "computer_browser_cua",
  "computer_element_action",
  "computer_use",
  "computer_use_bridge",
]);

function redactInteractiveFields(value, key = "", depth = 0) {
  if (depth > 8) return "<depth-limit>";
  if (/^(value|text|prompt|content|keys|keypress|clipboard|data)$/iu.test(key)) return "<redacted-input>";
  if (Array.isArray(value)) return value.slice(0, 100).map((item) => redactInteractiveFields(item, key, depth + 1));
  if (value && typeof value === "object") {
    const output = {};
    for (const [childKey, childValue] of Object.entries(value).slice(0, 200)) {
      output[childKey] = redactInteractiveFields(childValue, childKey, depth + 1);
    }
    return output;
  }
  return value;
}

export function redactDeviceCallArguments(toolName, args) {
  if (toolName === "secure_input_submit") return "<secure-input-redacted>";
  const redacted = redactTrace(args ?? {});
  return INPUT_BEARING_TOOLS.has(String(toolName)) ? redactInteractiveFields(redacted) : redacted;
}

function redactAppSurfaceEvidence(value, key = "", depth = 0) {
  if (depth > 8) return "<depth-limit>";
  if (/^(text|name|description|placeholder|title|value|content|data)$/iu.test(key)) return "<redacted-ui-text>";
  if (Array.isArray(value)) return value.slice(0, 100).map((item) => redactAppSurfaceEvidence(item, key, depth + 1));
  if (value && typeof value === "object") {
    const output = {};
    for (const [childKey, childValue] of Object.entries(value).slice(0, 200)) {
      output[childKey] = redactAppSurfaceEvidence(childValue, childKey, depth + 1);
    }
    return output;
  }
  return value;
}

export function redactDeviceCallResult(toolName, result) {
  const redacted = redactTrace(result ?? null);
  if (String(toolName).startsWith("fabushi.app.")) return redactAppSurfaceEvidence(redacted);
  return INPUT_BEARING_TOOLS.has(String(toolName)) ? redactInteractiveFields(redacted) : redacted;
}

async function appendDeviceTrace(path, record) {
  if (!path) return;
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  await appendFile(path, `${JSON.stringify({ at: new Date().toISOString(), ...record })}\n`, { encoding: "utf8", mode: 0o600 });
}

function defaultDeviceId(env) {
  if (env.DEVICE_ID) return String(env.DEVICE_ID);
  if (env.GITHUB_RUN_ID) {
    const raw = `gha-${env.GITHUB_RUN_ID}-${env.GITHUB_RUN_ATTEMPT || "1"}-${env.GITHUB_JOB || "job"}`;
    return raw.replace(/[^a-zA-Z0-9._:-]/gu, "-").slice(0, 128);
  }
  return hostname().replace(/[^a-zA-Z0-9._:-]/gu, "-").slice(0, 128);
}

export function resolveDeviceAgentConfig(env = process.env) {
  const gatewayValue = String(env.DEVICE_GATEWAY_URL ?? "").trim();
  if (!gatewayValue) return null;
  const sessionFile = String(env.FABUSHI_ACCOUNT_SESSION_FILE ?? "").trim();
  const gatewayToken = sessionFile ? "session-file" : readConfiguredGatewayToken(env);
  if (!sessionFile && (gatewayToken.length < 24 || gatewayToken.length > 16 * 1024 || /[\r\n]/u.test(gatewayToken))) {
    throw new Error("A valid Fabushi account or device gateway token is required.");
  }
  const entry = String(env.DEVICE_LOCAL_MCP_ENTRY ?? "").trim();
  const explicitCommand = String(env.DEVICE_LOCAL_MCP_COMMAND ?? "").trim();
  const localUrl = String(env.DEVICE_LOCAL_MCP_URL ?? "").trim();
  let local;
  if (entry || explicitCommand) {
    const command = explicitCommand || process.execPath;
    const args = [...(entry ? [resolve(entry)] : []), ...parseJsonArray(env.DEVICE_LOCAL_MCP_ARGS_JSON, "DEVICE_LOCAL_MCP_ARGS_JSON")];
    local = {
      kind: "stdio",
      command,
      args,
      cwd: String(env.DEVICE_LOCAL_MCP_CWD || (entry ? resolve(entry, "..", "..") : process.cwd())),
      env: safeChildEnvironment(env, env.DEVICE_LOCAL_MCP_ELECTRON_NODE === "1"),
    };
  } else {
    const localToken = String(env.VPS_APP_TOKEN ?? "").trim();
    const url = localUrl || `http://127.0.0.1:${env.PORT ?? 8787}${env.MCP_PATH_PREFIX ?? "/mcp"}`;
    if (localToken.length < 24) throw new Error("VPS_APP_TOKEN must be at least 24 characters for an HTTP local MCP.");
    local = { kind: "http", url, token: localToken };
  }
  const deviceId = defaultDeviceId(env);
  const deviceName = String(env.DEVICE_NAME || (env.GITHUB_RUN_ID ? `GitHub Actions ${env.GITHUB_REPOSITORY || "Runner"} #${env.GITHUB_RUN_ID}` : hostname())).trim();
  if (!/^[a-zA-Z0-9._:-]{1,128}$/u.test(deviceId)) throw new Error("DEVICE_ID is invalid.");
  if (!deviceName || deviceName.length > 200) throw new Error("DEVICE_NAME is invalid.");
  const leaseSeconds = Math.min(Math.max(Number(env.DEVICE_LEASE_SECONDS) || 2 * 60 * 60, MIN_LEASE_SECONDS), MAX_LEASE_SECONDS);
  return {
    gatewayUrl: safeGatewayUrl(gatewayValue, env),
    gatewayToken: sessionFile ? "" : gatewayToken,
    getGatewayToken: sessionFile
      ? () => createFabushiAccountSessionStore({ sessionPath: sessionFile, baseUrl: env.FABUSHI_API_BASE_URL }).accessToken()
      : null,
    local,
    deviceId,
    deviceName,
    leaseSeconds,
    metadata: runnerMetadata(env),
    tracePath: String(env.FABUSHI_DEVICE_CALL_TRACE_FILE || "").trim(),
    ipFamily: [4, 6].includes(Number(env.DEVICE_GATEWAY_IP_FAMILY)) ? Number(env.DEVICE_GATEWAY_IP_FAMILY) : 0,
    meshIdentityPath: defaultMeshIdentityPath(env),
    meshTags: parseMeshTags(env.DEVICE_MESH_TAGS_JSON),
    meshPosture: meshPostureFromEnvironment(env), // GBF-412 mesh config
    directPath: {
      enabled: !/^(0|false|no)$/iu.test(String(env.FABUSHI_DIRECT_PATH_ENABLED ?? "1")),
      host: String(env.FABUSHI_DIRECT_BIND_HOST || "0.0.0.0"),
      port: Math.max(0, Math.min(65535, Number(env.FABUSHI_DIRECT_BIND_PORT) || 0)),
      stunHost: String(env.FABUSHI_STUN_HOST || "").trim(),
      stunPort: Math.max(1, Math.min(65535, Number(env.FABUSHI_STUN_PORT) || 3478)),
    }, // GBF-412 direct path config
  };
}

export async function openDeviceLocalClient(config) {
  let transport;
  if (config.local.kind === "stdio") {
    transport = new StdioClientTransport({
      command: config.local.command,
      args: config.local.args,
      cwd: config.local.cwd,
      env: config.local.env,
      stderr: "inherit",
    });
  } else {
    transport = new StreamableHTTPClientTransport(new URL(config.local.url), {
      requestInit: { headers: { Authorization: `Bearer ${config.local.token}` } },
    });
  }
  const client = new Client({ name: "fabushi-device-agent", version: "1.0.0" });
  try {
    await client.connect(transport);
    const listed = await client.listTools();
    const toolDescriptors = buildToolCatalog(listed.tools);
    const capabilities = toolDescriptors.map((tool) => tool.name);
    const toolSchemaVersion = createHash("sha256").update(canonicalMeshJson(toolDescriptors)).digest("hex"); // GBF-412 canonical agent schema hash
    return { client, transport, capabilities, toolDescriptors, toolSchemaVersion };
  } catch (error) {
    await client.close().catch(() => {});
    throw error;
  }
}

async function runSecureInput(local, secureChannel, args) {
  const challengeId = String(args?.challengeId || "");
  if (!/^[a-f0-9-]{16,64}$/u.test(challengeId)) throw new Error("Invalid sensitive-input challenge.");
  const steps = Array.isArray(args?.steps) ? args.steps : [];
  if (!steps.length || steps.length > 10) throw new Error("Sensitive-input steps are invalid.");
  const values = await secureChannel.decrypt(args.envelope, challengeId);
  let completedSteps = 0;
  for (const step of steps) {
    const toolName = String(step?.toolName || "");
    if (!local.capabilities.includes(toolName) || toolName === "secure_input_submit") throw new Error(`Sensitive-input target tool ${toolName} is unavailable.`);
    const result = await local.client.callTool({ name: toolName, arguments: resolveSensitiveTemplate(step.arguments || {}, values) });
    if (result.isError) throw new Error(`Sensitive-input step ${completedSteps + 1} failed.`);
    completedSteps += 1;
  }
  return {
    content: [{ type: "text", text: `Sensitive input completed on the device (${completedSteps} step${completedSteps === 1 ? "" : "s"}).` }],
    structuredContent: { challengeId, status: "completed", completedSteps },
  };
}

export function startDeviceAgent(options = {}) {
  const config = options.config ?? resolveDeviceAgentConfig(options.env ?? process.env);
  if (!config) return null;
  const WebSocketImpl = options.WebSocketImpl ?? WebSocket;
  const openLocal = options.openLocalClient ?? openDeviceLocalClient;
  const log = options.log ?? console.log;
  const logError = options.error ?? console.error;
  let stopped = false;
  let registered = null;
  let reconnectMs = 1_000;
  let local = null;
  let secureChannel = null;
  let activeSocket = null;
  let reconnectTimer = null;
  const readyWaiters = new Set();
  const meshIdentity = options.meshIdentity ?? loadOrCreateMeshIdentity(
    config.meshIdentityPath ?? defaultMeshIdentityPath(options.env ?? process.env),
  ); // GBF-412 persistent node identity
  const invocationDeduper = createInvocationDeduper(); // GBF-412 exactly-once invocation boundary
  let directRpcTransport = null; // GBF-412 direct RPC lifecycle

  async function executeDeviceInvocation(invocationId, toolName, args) {
    return invocationDeduper.run(invocationId, async () => {
      return toolName === "secure_input_submit"
        ? await runSecureInput(local, secureChannel, args ?? {})
        : await local.client.callTool({ name: toolName, arguments: args ?? {} });
    });
  } // GBF-412 shared direct/relay execution boundary

  function announceRegistered(value) {
    registered = value;
    for (const waiter of readyWaiters) waiter.resolve(value);
    readyWaiters.clear();
  }

  function scheduleConnect(delay) {
    if (stopped || reconnectTimer) return;
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null;
      void connect();
    }, delay);
    reconnectTimer.unref?.();
  }

  const connect = async () => {
    if (stopped) return;
    try {
      if (!local) local = await openLocal(config);
      secureChannel = await createSecureInputChannel();
      const connectionGeneration = randomBytes(16).toString("hex");
      const directPeers = new Map();
      let directEndpoint = null;
      let directCandidates = [];
      if (config.directPath?.enabled) {
        directEndpoint = await bindDirectProbeEndpoint({
          identity: meshIdentity,
          deviceId: config.deviceId,
          generation: connectionGeneration,
          host: config.directPath.host,
          port: config.directPath.port,
          expectedPeer: (peerDeviceId) => {
            const peer = directPeers.get(peerDeviceId);
            return peer ? { fromDeviceId: peer.deviceId, fromGeneration: peer.generation, nodeKeyFingerprint: peer.nodeKeyFingerprint } : null;
          },
        });
        directCandidates = collectHostUdpCandidates(directEndpoint.address.port);
        if (config.directPath.stunHost) {
          try {
            const srflx = await discoverServerReflexiveCandidate({ socket: directEndpoint.socket, stunHost: config.directPath.stunHost, stunPort: config.directPath.stunPort });
            if (srflx) directCandidates = [...directCandidates, srflx];
          } catch (error) {
            logError(`Fabushi STUN endpoint discovery failed; relay remains available: ${error instanceof Error ? error.message : String(error)}`);
          }
        }
      } // GBF-412 establish direct probe endpoint
      const activeGatewayToken = config.getGatewayToken ? await config.getGatewayToken() : config.gatewayToken;
      const mesh = buildSignedMeshRegistration({
        identity: meshIdentity,
        deviceId: config.deviceId,
        generation: connectionGeneration,
        toolSchemaVersion: local.toolSchemaVersion,
        tags: config.meshTags,
        posture: config.meshPosture,
      }); // GBF-412 signed registration
      const socket = new WebSocketImpl(config.gatewayUrl, {
        headers: { Authorization: `Bearer ${activeGatewayToken}` },
        ...(config.ipFamily ? { family: config.ipFamily } : {}),
      });
      activeSocket = socket;
      let heartbeatTimer = null;
      let registrationTimer = null;
      let awaitingPong = false;
      let reconnectScheduled = false;

      socket.on("open", () => {
        reconnectMs = 1_000;
        socket.send(JSON.stringify({
          type: "register",
          deviceId: config.deviceId,
          name: config.deviceName,
          platform: platform(),
          capabilities: [...local.capabilities, "secure_input_submit"],
          tools: local.toolDescriptors,
          toolSchemaVersion: local.toolSchemaVersion,
          secureInputPublicKey: secureChannel.publicKey,
          generation: connectionGeneration,
          leaseSeconds: config.leaseSeconds,
          metadata: config.metadata,
          mesh, // GBF-412 signed node and relay path state
          ...(directEndpoint ? { direct: { version: "fabushi.direct-path.v1", candidates: directCandidates } } : {}),
        })); // GBF-412 publish direct candidates
        registrationTimer = setTimeout(() => {
          logError("Fabushi device gateway registration timed out; reconnecting.");
          socket.terminate();
        }, REGISTRATION_TIMEOUT_MS);
        registrationTimer.unref?.();
        heartbeatTimer = setInterval(() => {
          if (socket.readyState !== WebSocketImpl.OPEN) return;
          if (awaitingPong) {
            logError("Fabushi device gateway heartbeat timed out; reconnecting.");
            socket.terminate();
            return;
          }
          awaitingPong = true;
          socket.ping();
          socket.send(JSON.stringify({
            type: "heartbeat",
            at: Date.now(),
            mesh: { activePath: "relay", posture: config.meshPosture ?? {} },
            ...(directEndpoint ? { direct: { version: "fabushi.direct-path.v1", candidates: directCandidates } } : {}),
          })); // GBF-412 mesh heartbeat and direct candidate refresh
        }, HEARTBEAT_MS);
        heartbeatTimer.unref?.();
      });

      socket.on("pong", () => { awaitingPong = false; });
      socket.on("message", async (raw) => {
        let message;
        try { message = JSON.parse(raw.toString("utf8")); } catch { return; }
        if (message.type === "registered") {
          if (registrationTimer) clearTimeout(registrationTimer);
          registrationTimer = null;
          announceRegistered({ deviceId: config.deviceId, name: config.deviceName, expiresAt: message.expiresAt || null });
          log(`Fabushi device agent registered with ${new URL(config.gatewayUrl).host} as ${config.deviceId}.`);
          return;
        }
        if (message.type === "direct_peer_map") {
          if (!directEndpoint || message.version !== "fabushi.direct-path.v1" || !Array.isArray(message.peers)) return;
          directPeers.clear();
          for (const peer of message.peers.slice(0, 50)) {
            if (!peer?.deviceId || !peer?.generation || !peer?.nodeKeyFingerprint || !Array.isArray(peer.candidates)) continue;
            directPeers.set(String(peer.deviceId), peer);
          }
          if (!directRpcTransport && typeof message.accountBinding === "string" && message.accountBinding.length >= 16) {
            directRpcTransport = attachDirectRpcTransport({
              endpoint: directEndpoint,
              identity: meshIdentity,
              accountBinding: message.accountBinding,
              deviceId: config.deviceId,
              generation: connectionGeneration,
              peerLookup: (peerDeviceId) => directPeers.get(String(peerDeviceId)) ?? null,
              executeInvocation: executeDeviceInvocation,
            });
          } // GBF-412 attach account-bound encrypted peer RPC
          for (const peer of directPeers.values()) {
            for (const candidate of peer.candidates.slice(0, 8)) {
              if (!candidate?.id || !candidate?.host || !candidate?.port) continue;
              const started = Date.now();
              directEndpoint.probe({ peer, candidate, timeoutMs: 1_500 })
                .then((result) => {
                  if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_path_health", targetDeviceId: peer.deviceId, candidateId: candidate.id, reachable: true, latencyMs: result.latencyMs, loss: 0 }));
                })
                .catch(() => {
                  if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_path_health", targetDeviceId: peer.deviceId, candidateId: candidate.id, reachable: false, latencyMs: Date.now() - started, loss: 1 }));
                });
            }
          }
          return;
        } // GBF-412 probe same-account peers
        if (message.type === "direct_forward_call") {
          const requestId = String(message.requestId || "").slice(0, 128);
          const invocationId = String(message.invocationId || requestId).slice(0, 128);
          const targetDeviceId = String(message.targetDeviceId || "").slice(0, 128);
          const peer = directPeers.get(targetDeviceId);
          const candidate = peer?.candidates?.find((entry) => entry?.health?.reachable === true) ?? peer?.candidates?.[0];
          if (!directRpcTransport || !peer || peer.generation !== String(message.targetGeneration || "") || !candidate) {
            if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_forward_failed", requestId, invocationId, error: "No authenticated direct route is available." }));
            return;
          }
          directRpcTransport.call({
            peer, candidate, toolName: String(message.toolName || "").slice(0, 128), arguments: message.arguments ?? {}, invocationId,
            timeoutMs: Math.max(500, Math.min(5_000, Number(message.timeoutMs) || 2_500)),
          }).then((response) => {
            if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "result", requestId, invocationId, ok: response.result?.isError !== true, result: response.result, route: "direct-udp" }));
          }).catch((error) => {
            if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_forward_failed", requestId, invocationId, error: error instanceof Error ? error.message.slice(0, 1_000) : String(error).slice(0, 1_000) }));
          });
          return;
        } // GBF-412 peer direct forwarding
        if (message.type !== "call" || !message.requestId || !message.toolName) return;
        const invocationId = String(message.invocationId || message.requestId).slice(0, 128); // GBF-412 stable transport-independent invocation
        const traceBase = {
          requestId: String(message.requestId).slice(0, 128),
          invocationId,
          deviceId: config.deviceId,
          toolName: String(message.toolName).slice(0, 128),
          arguments: redactDeviceCallArguments(message.toolName, message.arguments ?? {}),
        };
        await appendDeviceTrace(config.tracePath, { ...traceBase, phase: "requested" }).catch(() => {});
        try {
          const result = await executeDeviceInvocation(invocationId, message.toolName, message.arguments ?? {}); // GBF-412 execute once across direct/relay retries // GBF-412 shared execution used by relay
          await appendDeviceTrace(config.tracePath, {
            ...traceBase,
            phase: "completed",
            ok: !result.isError,
            structuredContent: redactDeviceCallResult(message.toolName, result.structuredContent ?? null),
          }).catch(() => {});
          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, invocationId, ok: !result.isError, result })); // GBF-412 echo invocation id
        } catch (error) {
          await appendDeviceTrace(config.tracePath, { ...traceBase, phase: "completed", ok: false, error: error instanceof Error ? error.message.slice(0, 1_000) : String(error).slice(0, 1_000) }).catch(() => {});
          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, invocationId, ok: false, error: error instanceof Error ? error.message : String(error) })); // GBF-412 echo failed invocation id
        }
      });

      const scheduleReconnect = () => {
        if (reconnectScheduled) return;
        reconnectScheduled = true;
        registered = null;
        if (heartbeatTimer) clearInterval(heartbeatTimer);
        if (registrationTimer) clearTimeout(registrationTimer);
        if (activeSocket === socket) activeSocket = null;
        if (directRpcTransport) { try { directRpcTransport.close(); } catch {} directRpcTransport = null; } // GBF-412 close direct RPC on reconnect
        if (directEndpoint) { try { directEndpoint.close(); } catch {} directEndpoint = null; } // GBF-412 close direct socket on reconnect
        if (stopped) return;
        const delay = reconnectMs;
        reconnectMs = Math.min(reconnectMs * 2, MAX_RECONNECT_MS);
        scheduleConnect(delay);
      };
      socket.once("close", scheduleReconnect);
      socket.once("error", () => socket.terminate());
    } catch (error) {
      logError(`Fabushi device agent connection failed: ${error instanceof Error ? error.message : String(error)}`);
      if (local) {
        await local.client.close().catch(() => {});
        local = null;
      }
      const delay = reconnectMs;
      reconnectMs = Math.min(reconnectMs * 2, MAX_RECONNECT_MS);
      scheduleConnect(delay);
    }
  };

  void connect();
  return {
    config: { ...config, gatewayToken: undefined, getGatewayToken: undefined, local: config.local.kind === "http" ? { ...config.local, token: undefined } : config.local },
    waitUntilRegistered(timeoutMs = 30_000) {
      if (registered) return Promise.resolve(registered);
      return new Promise((resolveReady, rejectReady) => {
        const waiter = { resolve: resolveReady, reject: rejectReady };
        readyWaiters.add(waiter);
        const timer = setTimeout(() => {
          readyWaiters.delete(waiter);
          rejectReady(new Error(`Fabushi device agent did not register within ${timeoutMs}ms.`));
        }, timeoutMs);
        timer.unref?.();
        waiter.resolve = (value) => { clearTimeout(timer); resolveReady(value); };
      });
    },
    async stop() {
      stopped = true;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      for (const waiter of readyWaiters) waiter.reject(new Error("Fabushi device agent stopped."));
      readyWaiters.clear();
      if (activeSocket) activeSocket.close(1000, "device agent stopped");
      if (local) await local.client.close().catch(() => {});
    },
  };
}
