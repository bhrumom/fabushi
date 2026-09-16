#!/usr/bin/env node

import { existsSync, lstatSync, readFileSync, realpathSync } from "node:fs";
import { isAbsolute, join, relative, sep } from "node:path";
import { spawn } from "node:child_process";

const root = process.argv[2];
const MAX_OUTPUT_BYTES = 64 * 1024;
const SERVER_TIMEOUT_MS = 8_000;
const SAFE_ENV = {
  PATH: "/usr/local/bin:/usr/bin:/bin",
  HOME: "/tmp/fabushi-sandbox-home",
  TMPDIR: "/tmp",
  NODE_OPTIONS: "",
};

function fail(message) {
  process.stderr.write(`marketplace sandbox probe failed: ${message}\n`);
  process.exitCode = 1;
}

function insideRoot(candidate) {
  const resolved = realpathSync(candidate);
  const rel = relative(root, resolved);
  return rel === "" || (!rel.startsWith(`..${sep}`) && rel !== ".." && !isAbsolute(rel));
}

function localExecutable(command) {
  if (isAbsolute(command) || !command || command.includes("\\") || command.includes("\0")) {
    return null;
  }
  const candidate = join(root, command);
  if (!existsSync(candidate) || !insideRoot(candidate) || lstatSync(candidate).isSymbolicLink()) {
    return null;
  }
  return candidate;
}

function declaredServers() {
  const configPath = join(root, ".mcp.json");
  if (!existsSync(configPath)) return [];
  let config;
  try {
    config = JSON.parse(readFileSync(configPath, "utf8"));
  } catch {
    throw new Error(".mcp.json is not valid JSON");
  }
  const servers = config?.mcpServers ?? config?.servers ?? {};
  if (!servers || typeof servers !== "object" || Array.isArray(servers)) {
    throw new Error(".mcp.json must declare an object of stdio servers");
  }
  return Object.entries(servers).map(([name, server]) => {
    if (!server || typeof server !== "object" || Array.isArray(server)) {
      throw new Error(`server ${name} is invalid`);
    }
    if (server.type && server.type !== "stdio") {
      throw new Error(`server ${name} is not a stdio server`);
    }
    if (typeof server.command !== "string" || !server.command.trim()) {
      throw new Error(`server ${name} has no command`);
    }
    if (!Array.isArray(server.args) || server.args.some((arg) => typeof arg !== "string")) {
      throw new Error(`server ${name} args must be an array of strings`);
    }
    return { name, command: server.command.trim(), args: server.args };
  });
}

function jsonRpcLine(line) {
  try {
    const value = JSON.parse(line);
    return value && typeof value === "object" && value.jsonrpc === "2.0";
  } catch {
    return false;
  }
}

async function probeServer(server) {
  let command;
  if (server.command === "node" || server.command === "nodejs") {
    const script = server.args[0];
    if (!script || script.startsWith("-") || !localExecutable(script)) {
      throw new Error(`server ${server.name} must start with a package-local Node script`);
    }
    command = process.execPath;
  } else if (server.command.startsWith("./") || server.command.startsWith("../")) {
    command = localExecutable(server.command);
    if (!command) throw new Error(`server ${server.name} command escapes the package`);
  } else {
    throw new Error(`server ${server.name} uses an unapproved command`);
  }
  for (const arg of server.args) {
    if (isAbsolute(arg) || arg.includes("\0")) {
      throw new Error(`server ${server.name} has an absolute or invalid argument`);
    }
  }

  await new Promise((resolve, reject) => {
    const child = spawn(command, server.args, {
      cwd: root,
      env: SAFE_ENV,
      shell: false,
      stdio: ["pipe", "pipe", "pipe"],
    });
    let output = "";
    let sawRpc = false;
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      child.kill("SIGKILL");
      error ? reject(error) : resolve();
    };
    const consume = (chunk) => {
      if (output.length < MAX_OUTPUT_BYTES) {
        output += chunk.toString("utf8").slice(0, MAX_OUTPUT_BYTES - output.length);
      }
      for (const line of output.split(/\r?\n/)) {
        if (jsonRpcLine(line)) sawRpc = true;
      }
      if (sawRpc) finish();
    };
    child.stdout.on("data", consume);
    child.stderr.on("data", () => {});
    child.once("error", (error) => finish(new Error(`server ${server.name} could not start: ${error.message}`)));
    child.once("exit", (code) => {
      if (!sawRpc) finish(new Error(`server ${server.name} produced no JSON-RPC response (exit ${code ?? "unknown"})`));
    });
    const timer = setTimeout(() => finish(new Error(`server ${server.name} timed out`)), SERVER_TIMEOUT_MS);
    const initialize = {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "fabushi-marketplace-sandbox", version: "1" },
      },
    };
    child.stdin.end(`${JSON.stringify(initialize)}\n${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" })}\n`);
  });
}

try {
  if (!root || !isAbsolute(root) || !existsSync(root) || !insideRoot(root)) {
    throw new Error("package root is invalid");
  }
  const servers = declaredServers();
  for (const server of servers) await probeServer(server);
  process.stdout.write(JSON.stringify({
    schemaVersion: 1,
    status: "passed",
    mode: servers.length ? "stdio-jsonrpc" : "no-declared-stdio-runtime",
    servers: servers.length,
  }));
} catch (error) {
  fail(error instanceof Error ? error.message : "unknown sandbox failure");
}
