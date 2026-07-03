#!/usr/bin/env node
import http from "node:http";
import os from "node:os";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";

const PORT = Number(process.env.HERMES_HOST_PORT || 17393);
const HOST = process.env.HERMES_HOST_BIND || "127.0.0.1";
const MAX_BODY_BYTES = 1024 * 1024;
const DEFAULT_TIMEOUT_MS = Number(process.env.HERMES_CHAT_TIMEOUT_MS || 90000);
const DEFAULT_IDLE_MS = Number(process.env.HERMES_CHAT_IDLE_MS || 1400);

const installSessions = new Map();
let chatSession = null;

function nowIso() {
  return new Date().toISOString();
}

function isAlive(session) {
  return Boolean(session?.child && !session.child.killed && session.status === "running");
}

function shellQuote(value) {
  return `'${String(value ?? "").replace(/'/g, "'\\''")}'`;
}

function powershellEncodedCommand(value) {
  return Buffer.from(String(value ?? ""), "utf16le").toString("base64");
}

function redact(text, secrets = []) {
  let safe = String(text ?? "");
  for (const secret of secrets) {
    if (!secret || String(secret).length < 4) continue;
    safe = safe.split(String(secret)).join("[secret hidden]");
  }
  return safe;
}

function pushLog(session, role, text, level = "info") {
  if (!text) return;
  const chunks = String(text).split(/\r?\n/);
  for (const chunk of chunks) {
    if (!chunk.trim()) continue;
    session.seq += 1;
    session.logs.push({
      seq: session.seq,
      id: `${session.id}:${session.seq}`,
      role,
      level,
      text: redact(chunk, session.secrets),
      createdAt: nowIso(),
    });
  }
  if (session.logs.length > 600) session.logs.splice(0, session.logs.length - 600);
}

function buildInstallEnv(config = {}) {
  const env = {
    ...process.env,
    HERMES_INSTALL_SOURCE: "fabushi-chat-miniapp",
  };
  if (config.installDir) env.HERMES_HOME = String(config.installDir);
  if (config.model) env.HERMES_MODEL = String(config.model);
  if (config.apiBase) env.HERMES_API_BASE = String(config.apiBase);
  if (config.apiKey) {
    env.HERMES_API_KEY = String(config.apiKey);
    env.OPENAI_API_KEY = String(config.apiKey);
  }
  if (config.provider) env.HERMES_PROVIDER = String(config.provider);
  return env;
}

function buildInstallCommand(config = {}) {
  if (process.env.HERMES_INSTALL_COMMAND) return process.env.HERMES_INSTALL_COMMAND;

  const setupMode = String(config.setupMode || "portal");
  if (process.platform === "win32") {
    const setupCommand = setupMode === "portal" ? "hermes setup --portal" : "hermes setup";
    const encodedCommand = powershellEncodedCommand([
      "iex (irm https://hermes-agent.nousresearch.com/install.ps1)",
      setupCommand,
      "hermes doctor",
      "hermes --version",
    ].join("; "));
    return [
      "powershell",
      "-NoProfile",
      "-ExecutionPolicy Bypass",
      "-EncodedCommand",
      encodedCommand,
    ].join(" ");
  }

  const lines = [
    "set -e",
    "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash",
    'export PATH="$HOME/.local/bin:$PATH"',
  ];

  if (setupMode === "portal") {
    lines.push("hermes setup --portal");
  } else {
    lines.push('test -z "$HERMES_MODEL" || hermes config set model "$HERMES_MODEL" || true');
    lines.push('test -z "$HERMES_API_BASE" || hermes config set api_base "$HERMES_API_BASE" || true');
    lines.push('test -z "$HERMES_API_KEY" || hermes config set OPENAI_API_KEY "$HERMES_API_KEY" || true');
    lines.push("hermes setup");
  }

  lines.push("hermes doctor || true");
  lines.push("hermes --version || true");
  return `bash -lc ${shellQuote(lines.join("\n"))}`;
}

function startInstallSession(config = {}) {
  const id = randomUUID();
  const secrets = [config.apiKey, process.env.HERMES_API_KEY, process.env.OPENAI_API_KEY].filter(Boolean);
  const session = {
    id,
    kind: "install",
    status: "running",
    seq: 0,
    logs: [],
    secrets,
    startedAt: nowIso(),
    command: buildInstallCommand(config),
    child: null,
  };
  installSessions.set(id, session);

  pushLog(session, "assistant", "Hermes 安装会话已启动。终端输出会继续回到聊天框；如果安装器提问，直接在聊天框回复即可。");
  const child = spawn(session.command, {
    cwd: os.homedir(),
    env: buildInstallEnv(config),
    shell: true,
    stdio: ["pipe", "pipe", "pipe"],
    windowsHide: false,
  });
  session.child = child;

  child.stdout.on("data", (chunk) => pushLog(session, "terminal", chunk.toString("utf8")));
  child.stderr.on("data", (chunk) => pushLog(session, "terminal", chunk.toString("utf8"), "warn"));
  child.on("error", (error) => {
    session.status = "failed";
    pushLog(session, "assistant", `Hermes 安装进程启动失败：${error.message}`, "error");
  });
  child.on("exit", (code, signal) => {
    session.status = code === 0 ? "installed" : "failed";
    session.exitCode = code;
    session.signal = signal;
    session.endedAt = nowIso();
    pushLog(
      session,
      "assistant",
      code === 0
        ? "Hermes 安装完成。现在可以继续在聊天框里和 Hermes 对话。"
        : `Hermes 安装退出：code=${code ?? "null"} signal=${signal ?? "null"}`,
      code === 0 ? "info" : "error",
    );
  });

  return session;
}

function writeInstallReply(session, text) {
  if (!isAlive(session)) {
    pushLog(session, "assistant", "当前安装进程不在运行中，无法继续发送输入。", "warn");
    return false;
  }
  const value = String(text ?? "");
  pushLog(session, "user", value.match(/key|token|sk-/i) ? "[已发送隐藏输入]" : value);
  session.child.stdin.write(`${value}\n`);
  return true;
}

function startChatSession(config = {}) {
  if (chatSession?.child && !chatSession.child.killed) return chatSession;

  const command = process.env.HERMES_CHAT_COMMAND || String(config.chatCommand || "hermes");
  const session = {
    id: randomUUID(),
    kind: "chat",
    status: "running",
    seq: 0,
    logs: [],
    secrets: [config.apiKey, process.env.HERMES_API_KEY, process.env.OPENAI_API_KEY].filter(Boolean),
    startedAt: nowIso(),
    command,
    child: null,
  };
  chatSession = session;
  pushLog(session, "assistant", "Hermes 对话进程已连接。");

  const child = spawn(command, {
    cwd: process.cwd(),
    env: buildInstallEnv(config),
    shell: true,
    stdio: ["pipe", "pipe", "pipe"],
    windowsHide: false,
  });
  session.child = child;
  child.stdout.on("data", (chunk) => pushLog(session, "hermes", chunk.toString("utf8")));
  child.stderr.on("data", (chunk) => pushLog(session, "terminal", chunk.toString("utf8"), "warn"));
  child.on("error", (error) => {
    session.status = "failed";
    pushLog(session, "assistant", `Hermes 对话进程启动失败：${error.message}`, "error");
  });
  child.on("exit", (code, signal) => {
    session.status = "stopped";
    session.exitCode = code;
    session.signal = signal;
    session.endedAt = nowIso();
    pushLog(session, "assistant", `Hermes 对话进程已退出：code=${code ?? "null"} signal=${signal ?? "null"}`);
  });
  return session;
}

function waitForChatOutput(session, afterSeq, timeoutMs = DEFAULT_TIMEOUT_MS, idleMs = DEFAULT_IDLE_MS) {
  return new Promise((resolve) => {
    const startedAt = Date.now();
    let lastSeq = session.seq;
    let lastChangeAt = Date.now();

    const timer = setInterval(() => {
      if (session.seq !== lastSeq) {
        lastSeq = session.seq;
        lastChangeAt = Date.now();
      }
      const hasOutput = session.logs.some((item) => item.seq > afterSeq && item.role !== "user");
      const idle = hasOutput && Date.now() - lastChangeAt >= idleMs;
      const timedOut = Date.now() - startedAt >= timeoutMs;
      const stopped = session.status !== "running";
      if (idle || timedOut || stopped) {
        clearInterval(timer);
        resolve(session.logs.filter((item) => item.seq > afterSeq && item.role !== "user"));
      }
    }, 250);
  });
}

async function sendChatMessage(message, config = {}) {
  const session = startChatSession(config);
  if (!session.child || session.child.killed) {
    throw new Error("Hermes chat process is not running.");
  }
  const afterSeq = session.seq;
  pushLog(session, "user", message);
  session.child.stdin.write(`${String(message ?? "")}\n`);
  const logs = await waitForChatOutput(session, afterSeq);
  const reply = logs
    .filter((item) => item.role === "hermes" || item.role === "assistant" || item.role === "terminal")
    .map((item) => item.text)
    .join("\n")
    .trim();
  return {
    sessionId: session.id,
    status: session.status,
    logs,
    reply: reply || "Hermes 暂未输出内容；会话仍保持连接。",
  };
}

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json; charset=utf-8",
  });
  res.end(JSON.stringify(payload));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error("Request body is too large."));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      const text = Buffer.concat(chunks).toString("utf8").trim();
      if (!text) return resolve({});
      try {
        resolve(JSON.parse(text));
      } catch (error) {
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

function getInstallStatus(id, after = 0) {
  const session = installSessions.get(id);
  if (!session) return null;
  return {
    sessionId: session.id,
    status: session.status,
    exitCode: session.exitCode,
    signal: session.signal,
    startedAt: session.startedAt,
    endedAt: session.endedAt,
    logs: session.logs.filter((item) => item.seq > after),
    lastSeq: session.seq,
  };
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "OPTIONS") {
      sendJson(res, 200, { ok: true });
      return;
    }

    const url = new URL(req.url || "/", `http://${HOST}:${PORT}`);
    if (req.method === "GET" && url.pathname === "/health") {
      sendJson(res, 200, {
        ok: true,
        service: "fabushi-hermes-chat-host",
        port: PORT,
        host: HOST,
        chatConnected: Boolean(chatSession?.child && !chatSession.child.killed),
      });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/hermes/install/start") {
      const body = await readJson(req);
      const session = startInstallSession(body.config || {});
      sendJson(res, 200, getInstallStatus(session.id, 0));
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/hermes/install/reply") {
      const body = await readJson(req);
      const session = installSessions.get(String(body.sessionId || ""));
      if (!session) {
        sendJson(res, 404, { ok: false, message: "install session not found" });
        return;
      }
      writeInstallReply(session, body.message || "");
      sendJson(res, 200, getInstallStatus(session.id, Number(body.after || 0)));
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/hermes/install/status") {
      const data = getInstallStatus(String(url.searchParams.get("id") || ""), Number(url.searchParams.get("after") || 0));
      if (!data) {
        sendJson(res, 404, { ok: false, message: "install session not found" });
        return;
      }
      sendJson(res, 200, data);
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/hermes/chat") {
      const body = await readJson(req);
      const message = String(body.message || "").trim();
      if (!message) {
        sendJson(res, 400, { ok: false, message: "message is required" });
        return;
      }
      const data = await sendChatMessage(message, body.config || {});
      sendJson(res, 200, { ok: true, ...data });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/hermes/chat/stop") {
      if (chatSession?.child && !chatSession.child.killed) {
        chatSession.child.kill("SIGTERM");
      }
      sendJson(res, 200, { ok: true, status: "stopped" });
      return;
    }

    sendJson(res, 404, { ok: false, message: "not found" });
  } catch (error) {
    sendJson(res, 500, {
      ok: false,
      message: error instanceof Error ? error.message : "unknown error",
    });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Hermes chat host listening on http://${HOST}:${PORT}`);
  console.log("Use HERMES_INSTALL_COMMAND or HERMES_CHAT_COMMAND to override defaults.");
});
