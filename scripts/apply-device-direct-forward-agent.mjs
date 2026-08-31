import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-agent.js");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing direct forwarding agent anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  'import { createInvocationDeduper } from "./device-direct-rpc.js"; // GBF-412 direct RPC dedupe\n',
  'import { createInvocationDeduper } from "./device-direct-rpc.js"; // GBF-412 direct RPC dedupe\n' +
    'import { attachDirectRpcTransport } from "./device-direct-transport.js"; // GBF-412 encrypted peer RPC transport\n',
  '// GBF-412 encrypted peer RPC transport',
);

replaceOnce(
  '  const invocationDeduper = createInvocationDeduper(); // GBF-412 exactly-once invocation boundary\n',
  '  const invocationDeduper = createInvocationDeduper(); // GBF-412 exactly-once invocation boundary\n' +
    '  let directRpcTransport = null; // GBF-412 direct RPC lifecycle\n',
  '// GBF-412 direct RPC lifecycle',
);

replaceOnce(
  '  function announceRegistered(value) {\n',
  '  async function executeDeviceInvocation(invocationId, toolName, args) {\n' +
    '    return invocationDeduper.run(invocationId, async () => {\n' +
    '      return toolName === "secure_input_submit"\n' +
    '        ? await runSecureInput(local, secureChannel, args ?? {})\n' +
    '        : await local.client.callTool({ name: toolName, arguments: args ?? {} });\n' +
    '    });\n' +
    '  } // GBF-412 shared direct/relay execution boundary\n\n' +
    '  function announceRegistered(value) {\n',
  '// GBF-412 shared direct/relay execution boundary',
);

replaceOnce(
  '          const result = await invocationDeduper.run(invocationId, async () => {\n            return message.toolName === "secure_input_submit"\n              ? await runSecureInput(local, secureChannel, message.arguments ?? {})\n              : await local.client.callTool({ name: message.toolName, arguments: message.arguments ?? {} });\n          }); // GBF-412 execute once across direct/relay retries\n',
  '          const result = await executeDeviceInvocation(invocationId, message.toolName, message.arguments ?? {}); // GBF-412 execute once across direct/relay retries\n',
  '// GBF-412 shared execution used by relay',
);
source = source.replace(
  '          const result = await executeDeviceInvocation(invocationId, message.toolName, message.arguments ?? {}); // GBF-412 execute once across direct/relay retries\n',
  '          const result = await executeDeviceInvocation(invocationId, message.toolName, message.arguments ?? {}); // GBF-412 execute once across direct/relay retries // GBF-412 shared execution used by relay\n',
);

replaceOnce(
  '          for (const peer of directPeers.values()) {\n',
  '          if (!directRpcTransport && typeof message.accountBinding === "string" && message.accountBinding.length >= 16) {\n' +
    '            directRpcTransport = attachDirectRpcTransport({\n' +
    '              endpoint: directEndpoint,\n' +
    '              identity: meshIdentity,\n' +
    '              accountBinding: message.accountBinding,\n' +
    '              deviceId: config.deviceId,\n' +
    '              generation: connectionGeneration,\n' +
    '              peerLookup: (peerDeviceId) => directPeers.get(String(peerDeviceId)) ?? null,\n' +
    '              executeInvocation: executeDeviceInvocation,\n' +
    '            });\n' +
    '          } // GBF-412 attach account-bound encrypted peer RPC\n' +
    '          for (const peer of directPeers.values()) {\n',
  '// GBF-412 attach account-bound encrypted peer RPC',
);

replaceOnce(
  '        } // GBF-412 probe same-account peers\n        if (message.type !== "call" || !message.requestId || !message.toolName) return;\n',
  '        } // GBF-412 probe same-account peers\n' +
    '        if (message.type === "direct_forward_call") {\n' +
    '          const requestId = String(message.requestId || "").slice(0, 128);\n' +
    '          const invocationId = String(message.invocationId || requestId).slice(0, 128);\n' +
    '          const targetDeviceId = String(message.targetDeviceId || "").slice(0, 128);\n' +
    '          const peer = directPeers.get(targetDeviceId);\n' +
    '          const candidate = peer?.candidates?.find((entry) => entry?.health?.reachable === true) ?? peer?.candidates?.[0];\n' +
    '          if (!directRpcTransport || !peer || peer.generation !== String(message.targetGeneration || "") || !candidate) {\n' +
    '            if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_forward_failed", requestId, invocationId, error: "No authenticated direct route is available." }));\n' +
    '            return;\n' +
    '          }\n' +
    '          directRpcTransport.call({\n' +
    '            peer, candidate, toolName: String(message.toolName || "").slice(0, 128), arguments: message.arguments ?? {}, invocationId,\n' +
    '            timeoutMs: Math.max(500, Math.min(5_000, Number(message.timeoutMs) || 2_500)),\n' +
    '          }).then((response) => {\n' +
    '            if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "result", requestId, invocationId, ok: response.result?.isError !== true, result: response.result, route: "direct-udp" }));\n' +
    '          }).catch((error) => {\n' +
    '            if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_forward_failed", requestId, invocationId, error: error instanceof Error ? error.message.slice(0, 1_000) : String(error).slice(0, 1_000) }));\n' +
    '          });\n' +
    '          return;\n' +
    '        } // GBF-412 peer direct forwarding\n' +
    '        if (message.type !== "call" || !message.requestId || !message.toolName) return;\n',
  '// GBF-412 peer direct forwarding',
);

replaceOnce(
  '        if (directEndpoint) { try { directEndpoint.close(); } catch {} directEndpoint = null; } // GBF-412 close direct socket on reconnect\n',
  '        if (directRpcTransport) { try { directRpcTransport.close(); } catch {} directRpcTransport = null; } // GBF-412 close direct RPC on reconnect\n' +
    '        if (directEndpoint) { try { directEndpoint.close(); } catch {} directEndpoint = null; } // GBF-412 close direct socket on reconnect\n',
  '// GBF-412 close direct RPC on reconnect',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied encrypted peer forwarding to device agent." : "Direct forwarding agent integration already applied.");
