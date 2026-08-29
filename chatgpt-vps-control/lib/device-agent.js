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
  const prefixes = ["FABUSHI_COMPUTER_", "CHATGPT_COMPUTER_", "COMPUTER_", "MAHAYANA_COMPUTER_MCP_"];
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
    const toolSchemaVersion = createHash("sha256").update(JSON.stringify(toolDescriptors)).digest("hex");
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
      const activeGatewayToken = config.getGatewayToken ? await config.getGatewayToken() : config.gatewayToken;
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
        }));
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
          socket.send(JSON.stringify({ type: "heartbeat", at: Date.now() }));
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
        if (message.type !== "call" || !message.requestId || !message.toolName) return;
        const traceBase = {
          requestId: String(message.requestId).slice(0, 128),
          deviceId: config.deviceId,
          toolName: String(message.toolName).slice(0, 128),
          arguments: message.toolName === "secure_input_submit" ? "<secure-input-redacted>" : redactTrace(message.arguments ?? {}),
        };
        await appendDeviceTrace(config.tracePath, { ...traceBase, phase: "requested" }).catch(() => {});
        try {
          const result = message.toolName === "secure_input_submit"
            ? await runSecureInput(local, secureChannel, message.arguments ?? {})
            : await local.client.callTool({ name: message.toolName, arguments: message.arguments ?? {} });
          await appendDeviceTrace(config.tracePath, {
            ...traceBase,
            phase: "completed",
            ok: !result.isError,
            structuredContent: redactTrace(result.structuredContent ?? null),
          }).catch(() => {});
          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, ok: !result.isError, result }));
        } catch (error) {
          await appendDeviceTrace(config.tracePath, { ...traceBase, phase: "completed", ok: false, error: error instanceof Error ? error.message.slice(0, 1_000) : String(error).slice(0, 1_000) }).catch(() => {});
          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, ok: false, error: error instanceof Error ? error.message : String(error) }));
        }
      });

      const scheduleReconnect = () => {
        if (reconnectScheduled) return;
        reconnectScheduled = true;
        registered = null;
        if (heartbeatTimer) clearInterval(heartbeatTimer);
        if (registrationTimer) clearTimeout(registrationTimer);
        if (activeSocket === socket) activeSocket = null;
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
