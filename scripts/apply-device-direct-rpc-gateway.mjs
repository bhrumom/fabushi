import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-gateway.js");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing direct RPC gateway anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  '  const requestId = randomBytes(16).toString("hex");\n  const timeoutMs = Math.min(Math.max(Number(timeoutSeconds) || DEFAULT_CALL_TIMEOUT_SECONDS, 1), MAX_CALL_TIMEOUT_SECONDS) * 1000;\n',
  '  const invocationId = randomBytes(16).toString("hex"); // GBF-412 transport-independent invocation id\n' +
    '  const requestId = randomBytes(16).toString("hex");\n' +
    '  const timeoutMs = Math.min(Math.max(Number(timeoutSeconds) || DEFAULT_CALL_TIMEOUT_SECONDS, 1), MAX_CALL_TIMEOUT_SECONDS) * 1000;\n',
  '// GBF-412 transport-independent invocation id',
);

replaceOnce(
  '    pendingCalls.set(requestId, { registryKey: key, socket: device.socket, resolve, reject, timer });\n    device.socket.send(JSON.stringify({ type: "call", requestId, toolName, arguments: args }), (error) => {\n',
  '    pendingCalls.set(requestId, { registryKey: key, socket: device.socket, invocationId, resolve, reject, timer });\n' +
    '    device.socket.send(JSON.stringify({ type: "call", requestId, invocationId, toolName, arguments: args }), (error) => { // GBF-412 relay carries stable invocation id\n',
  '// GBF-412 relay carries stable invocation id',
);

replaceOnce(
  '    if (!pending || pending.registryKey !== socket.registryKey || pending.socket !== socket) return;\n    pendingCalls.delete(requestId);\n',
  '    if (!pending || pending.registryKey !== socket.registryKey || pending.socket !== socket) return;\n' +
    '    if (message.invocationId && String(message.invocationId) !== pending.invocationId) return; // GBF-412 bind result to invocation\n' +
    '    pendingCalls.delete(requestId);\n',
  '// GBF-412 bind result to invocation',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied stable invocation ids to gateway calls." : "Direct RPC gateway invocation ids already applied.");
