import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-agent.js");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing direct RPC agent anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  'import { bindDirectProbeEndpoint, collectHostUdpCandidates, discoverServerReflexiveCandidate } from "./device-direct-path.js"; // GBF-412 direct agent\n',
  'import { bindDirectProbeEndpoint, collectHostUdpCandidates, discoverServerReflexiveCandidate } from "./device-direct-path.js"; // GBF-412 direct agent\n' +
    'import { createInvocationDeduper } from "./device-direct-rpc.js"; // GBF-412 direct RPC dedupe\n',
  '// GBF-412 direct RPC dedupe',
);

replaceOnce(
  '  const meshIdentity = options.meshIdentity ?? loadOrCreateMeshIdentity(\n    config.meshIdentityPath ?? defaultMeshIdentityPath(options.env ?? process.env),\n  ); // GBF-412 persistent node identity\n',
  '  const meshIdentity = options.meshIdentity ?? loadOrCreateMeshIdentity(\n' +
    '    config.meshIdentityPath ?? defaultMeshIdentityPath(options.env ?? process.env),\n' +
    '  ); // GBF-412 persistent node identity\n' +
    '  const invocationDeduper = createInvocationDeduper(); // GBF-412 exactly-once invocation boundary\n',
  '// GBF-412 exactly-once invocation boundary',
);

replaceOnce(
  '        const traceBase = {\n          requestId: String(message.requestId).slice(0, 128),\n',
  '        const invocationId = String(message.invocationId || message.requestId).slice(0, 128); // GBF-412 stable transport-independent invocation\n' +
    '        const traceBase = {\n' +
    '          requestId: String(message.requestId).slice(0, 128),\n' +
    '          invocationId,\n',
  '// GBF-412 stable transport-independent invocation',
);

replaceOnce(
  '          const result = message.toolName === "secure_input_submit"\n            ? await runSecureInput(local, secureChannel, message.arguments ?? {})\n            : await local.client.callTool({ name: message.toolName, arguments: message.arguments ?? {} });\n',
  '          const result = await invocationDeduper.run(invocationId, async () => {\n' +
    '            return message.toolName === "secure_input_submit"\n' +
    '              ? await runSecureInput(local, secureChannel, message.arguments ?? {})\n' +
    '              : await local.client.callTool({ name: message.toolName, arguments: message.arguments ?? {} });\n' +
    '          }); // GBF-412 execute once across direct/relay retries\n',
  '// GBF-412 execute once across direct/relay retries',
);

replaceOnce(
  '          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, ok: !result.isError, result }));\n',
  '          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, invocationId, ok: !result.isError, result })); // GBF-412 echo invocation id\n',
  '// GBF-412 echo invocation id',
);

replaceOnce(
  '          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, ok: false, error: error instanceof Error ? error.message : String(error) }));\n',
  '          socket.send(JSON.stringify({ type: "result", requestId: message.requestId, invocationId, ok: false, error: error instanceof Error ? error.message : String(error) })); // GBF-412 echo failed invocation id\n',
  '// GBF-412 echo failed invocation id',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied transport-independent invocation dedupe to device agent." : "Direct RPC agent dedupe already applied.");
