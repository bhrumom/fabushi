import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-gateway.js");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing direct forwarding gateway anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  '        version: "fabushi.direct-path.v1",\n        peers: directPaths.peers(accountId, device.id),\n',
  '        version: "fabushi.direct-path.v1",\n' +
    '        accountBinding: createHash("sha256").update(String(accountId)).digest("base64url").slice(0, 32), // GBF-412 account-bound direct session\n' +
    '        peers: directPaths.peers(accountId, device.id),\n',
  '// GBF-412 account-bound direct session',
);

replaceOnce(
  '    if (!accepted) return;\n    const selected = options.directPaths.select(socket.accountId, target.id);\n',
  '    if (!accepted) return;\n' +
    '    if (message.reachable === true) target.directRouterId = reporter.id;\n' +
    '    else if (target.directRouterId === reporter.id) target.directRouterId = null; // GBF-412 remember authenticated direct reporter\n' +
    '    const selected = options.directPaths.select(socket.accountId, target.id);\n',
  '// GBF-412 remember authenticated direct reporter',
);

replaceOnce(
  '  if (message.type === "result") {\n',
  '  if (message.type === "direct_forward_failed") {\n' +
    '    const requestId = String(message.requestId ?? "");\n' +
    '    const pending = pendingCalls.get(requestId);\n' +
    '    if (!pending || pending.socket !== socket || pending.route !== "direct-udp") return;\n' +
    '    if (String(message.invocationId || "") !== pending.invocationId) return;\n' +
    '    const target = devices.get(pending.targetRegistryKey);\n' +
    '    if (!target || target.status !== "online" || !target.socket || target.socket.readyState !== 1) {\n' +
    '      pendingCalls.delete(requestId);\n' +
    '      clearTimeout(pending.timer);\n' +
    '      pending.reject(new Error(`Device ${pending.targetDeviceId} became unavailable during direct fallback.`));\n' +
    '      return;\n' +
    '    }\n' +
    '    pending.socket = target.socket;\n' +
    '    pending.registryKey = pending.targetRegistryKey;\n' +
    '    pending.route = "relay";\n' +
    '    target.socket.send(JSON.stringify({ type: "call", requestId, invocationId: pending.invocationId, toolName: pending.toolName, arguments: pending.arguments }), (error) => {\n' +
    '      if (!error) return;\n' +
    '      if (pendingCalls.get(requestId) !== pending) return;\n' +
    '      pendingCalls.delete(requestId);\n' +
    '      clearTimeout(pending.timer);\n' +
    '      pending.reject(error);\n' +
    '    });\n' +
    '    audit(options, { type: "device.direct_fallback", accountId: socket.accountId, routerDeviceId: socket.deviceId || "", targetDeviceId: pending.targetDeviceId, invocationId: pending.invocationId, reason: String(message.error || "direct forwarding failed").slice(0, 300) });\n' +
    '    return;\n' +
    '  } // GBF-412 direct to relay fallback with same invocation\n\n' +
    '  if (message.type === "result") {\n',
  '// GBF-412 direct to relay fallback with same invocation',
);

replaceOnce(
  '    pendingCalls.delete(requestId);\n    clearTimeout(pending.timer);\n    pending.resolve(message);\n',
  '    pendingCalls.delete(requestId);\n' +
    '    clearTimeout(pending.timer);\n' +
    '    message.route = message.route === "direct-udp" ? "direct-udp" : pending.route || "relay"; // GBF-412 route observability\n' +
    '    pending.resolve(message);\n',
  '// GBF-412 route observability',
);

replaceOnce(
  '  const pendingForDevice = [...pendingCalls.values()].filter((pending) => pending.registryKey === key).length;\n',
  '  const pendingForDevice = [...pendingCalls.values()].filter((pending) => (pending.targetRegistryKey || pending.registryKey) === key).length; // GBF-412 count forwarded calls against target\n',
  '// GBF-412 count forwarded calls against target',
);

replaceOnce(
  '  const timeoutMs = Math.min(Math.max(Number(timeoutSeconds) || DEFAULT_CALL_TIMEOUT_SECONDS, 1), MAX_CALL_TIMEOUT_SECONDS) * 1000;\n  return new Promise((resolve, reject) => {\n',
  '  const timeoutMs = Math.min(Math.max(Number(timeoutSeconds) || DEFAULT_CALL_TIMEOUT_SECONDS, 1), MAX_CALL_TIMEOUT_SECONDS) * 1000;\n' +
    '  const routerKey = device.directRouterId ? registryKey(accountId, device.directRouterId) : "";\n' +
    '  const router = routerKey ? devices.get(routerKey) : null;\n' +
    '  const useDirect = device.mesh?.activePath === "direct-udp"\n' +
    '    && router && router.id !== device.id && router.status === "online" && router.socket?.readyState === 1; // GBF-412 choose healthy peer router\n' +
    '  return new Promise((resolve, reject) => {\n',
  '// GBF-412 choose healthy peer router',
);

replaceOnce(
  '    pendingCalls.set(requestId, { registryKey: key, socket: device.socket, invocationId, resolve, reject, timer });\n    device.socket.send(JSON.stringify({ type: "call", requestId, invocationId, toolName, arguments: args }), (error) => { // GBF-412 relay carries stable invocation id\n',
  '    const responseSocket = useDirect ? router.socket : device.socket;\n' +
    '    const responseRegistryKey = useDirect ? routerKey : key;\n' +
    '    const pending = {\n' +
    '      registryKey: responseRegistryKey, targetRegistryKey: key, targetDeviceId: deviceId,\n' +
    '      socket: responseSocket, invocationId, toolName, arguments: args,\n' +
    '      route: useDirect ? "direct-udp" : "relay", resolve, reject, timer,\n' +
    '    };\n' +
    '    pendingCalls.set(requestId, pending);\n' +
    '    const outbound = useDirect\n' +
    '      ? { type: "direct_forward_call", requestId, invocationId, targetDeviceId: deviceId, targetGeneration: device.generation, toolName, arguments: args, timeoutMs: Math.min(timeoutMs, 5_000) }\n' +
    '      : { type: "call", requestId, invocationId, toolName, arguments: args };\n' +
    '    responseSocket.send(JSON.stringify(outbound), (error) => { // GBF-412 direct-first dispatch\n',
  '// GBF-412 direct-first dispatch',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied peer-routed direct-first device calls with relay fallback." : "Direct forwarding gateway integration already applied.");
