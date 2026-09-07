#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { connect } from "node:net";
import { homedir, platform, userInfo } from "node:os";
import { join } from "node:path";
import { browserExtensionPaths } from "../lib/browser-extension-paths.js";

const paths = browserExtensionPaths();
const secret = (await readFile(paths.secret, "utf8")).trim();
const socketPath = process.env.FABUSHI_CHROME_PLATFORM_SOCKET?.trim() || (platform() === "win32"
  ? `\\\\.\\pipe\\fabushi-chrome-platform-${createHash("sha256").update(userInfo().username).digest("hex").slice(0, 12)}`
  : join(process.env.COMPUTER_BROWSER_EXTENSION_HOME || join(homedir(), ".chatgpt-computer-control", "browser-extension"), "fabushi-platform.sock"));

let nativeBuffer = Buffer.alloc(0);
let lineBuffer = "";
let socket = null;
let reconnectTimer = null;
let authenticatedHello = null;
const pendingMessages = [];

function writeNative(message) {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  const header = Buffer.alloc(4);
  header.writeUInt32LE(body.length, 0);
  process.stdout.write(Buffer.concat([header, body]));
}

function forwardPlatformData(chunk) {
  lineBuffer += chunk;
  while (lineBuffer.includes("\n")) {
    const index = lineBuffer.indexOf("\n");
    const line = lineBuffer.slice(0, index);
    lineBuffer = lineBuffer.slice(index + 1);
    if (!line.trim()) continue;
    try { writeNative(JSON.parse(line)); }
    catch { socket?.destroy(); }
  }
}

function enqueue(message) {
  if (message.type === "platform_heartbeat") {
    const index = pendingMessages.findIndex((item) => item.type === message.type);
    if (index >= 0) pendingMessages.splice(index, 1);
  }
  pendingMessages.push(message);
  if (pendingMessages.length > 256) pendingMessages.splice(0, pendingMessages.length - 256);
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connectPlatform();
  }, 500);
}

function connectPlatform() {
  if (socket && !socket.destroyed) return;
  lineBuffer = "";
  const candidate = connect(socketPath);
  socket = candidate;
  candidate.setEncoding("utf8");
  candidate.on("connect", () => {
    if (authenticatedHello) candidate.write(`${JSON.stringify(authenticatedHello)}\n`);
    while (pendingMessages.length) candidate.write(`${JSON.stringify(pendingMessages.shift())}\n`);
  });
  candidate.on("data", forwardPlatformData);
  candidate.on("error", () => {});
  candidate.on("close", () => {
    if (socket === candidate) socket = null;
    scheduleReconnect();
  });
}

function sendPlatform(message) {
  if (message.type === "platform_hello") {
    authenticatedHello = { ...message, secret };
    if (socket && !socket.destroyed && socket.readyState === "open") socket.write(`${JSON.stringify(authenticatedHello)}\n`);
    else enqueue(authenticatedHello);
    return;
  }
  if (socket && !socket.destroyed && socket.readyState === "open") socket.write(`${JSON.stringify(message)}\n`);
  else enqueue(message);
}

connectPlatform();
process.stdin.on("data", (chunk) => {
  nativeBuffer = Buffer.concat([nativeBuffer, chunk]);
  while (nativeBuffer.length >= 4) {
    const length = nativeBuffer.readUInt32LE(0);
    if (length > 16 * 1024 * 1024) process.exit(2);
    if (nativeBuffer.length < 4 + length) return;
    let message;
    try { message = JSON.parse(nativeBuffer.subarray(4, 4 + length).toString("utf8")); }
    catch { process.exit(2); }
    nativeBuffer = nativeBuffer.subarray(4 + length);
    sendPlatform(message);
  }
});
process.stdin.on("end", () => {
  if (reconnectTimer) clearTimeout(reconnectTimer);
  socket?.end();
});
