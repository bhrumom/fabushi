import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-gateway.js");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing direct gateway integration anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  '} from "./device-mesh.js"; // GBF-412 mesh gateway\n',
  '} from "./device-mesh.js"; // GBF-412 mesh gateway\nimport { createDirectPathRegistry } from "./device-direct-path.js"; // GBF-412 direct rendezvous\n',
  '// GBF-412 direct rendezvous',
);

replaceOnce(
  'function audit(options, record) {\n',
  'function publishDirectPeerMaps(accountId, directPaths) {\n' +
    '  if (!directPaths || !accountId) return;\n' +
    '  for (const device of devices.values()) {\n' +
    '    if (device.accountId !== accountId || device.central || device.status !== "online" || !device.socket || device.socket.readyState !== 1) continue;\n' +
    '    try {\n' +
    '      device.socket.send(JSON.stringify({\n' +
    '        type: "direct_peer_map",\n' +
    '        version: "fabushi.direct-path.v1",\n' +
    '        peers: directPaths.peers(accountId, device.id),\n' +
    '      }));\n' +
    '    } catch {}\n' +
    '  }\n' +
    '} // GBF-412 same-account direct peer map\n\n' +
    'function audit(options, record) {\n',
  '// GBF-412 same-account direct peer map',
);

replaceOnce(
  '    socket.deviceId = id;\n    socket.registryKey = key;\n    socket.send(JSON.stringify({\n',
  '    socket.deviceId = id;\n' +
    '    socket.registryKey = key;\n' +
    '    if (mesh && options.directPaths) {\n' +
    '      const direct = options.directPaths.update({\n' +
    '        accountId: socket.accountId,\n' +
    '        deviceId: id,\n' +
    '        generation,\n' +
    '        nodeKeyFingerprint: mesh.nodeKeyFingerprint,\n' +
    '        candidates: message.direct?.candidates,\n' +
    '        leaseExpiresAt: expiresAt,\n' +
    '      });\n' +
    '      if (direct.candidates.length) {\n' +
    '        mesh.supportedPaths = [...new Set(["direct-udp", ...mesh.supportedPaths])];\n' +
    '        mesh.preferredPath = "direct-udp";\n' +
    '      }\n' +
    '    } // GBF-412 direct candidate enrollment\n' +
    '    socket.send(JSON.stringify({\n',
  '// GBF-412 direct candidate enrollment',
);

replaceOnce(
  '      mesh: publicMeshState(mesh),\n    }));\n    audit(options, {\n',
  '      mesh: publicMeshState(mesh),\n' +
    '      ...(options.directPaths ? { directPeers: options.directPaths.peers(socket.accountId, id) } : {}),\n' +
    '    }));\n' +
    '    publishDirectPeerMaps(socket.accountId, options.directPaths); // GBF-412 publish rendezvous after register\n' +
    '    audit(options, {\n',
  '// GBF-412 publish rendezvous after register',
);

replaceOnce(
  '      device.mesh = mergeMeshHeartbeat(device.mesh, message.mesh); // GBF-412 heartbeat posture/path\n      device.status = device.expiresAt > Date.now() ? "online" : "offline";\n',
  '      device.mesh = mergeMeshHeartbeat(device.mesh, message.mesh); // GBF-412 heartbeat posture/path\n' +
    '      if (device.mesh && options.directPaths && message.direct?.candidates) {\n' +
    '        const direct = options.directPaths.update({\n' +
    '          accountId: socket.accountId,\n' +
    '          deviceId: device.id,\n' +
    '          generation: device.generation,\n' +
    '          nodeKeyFingerprint: device.mesh.nodeKeyFingerprint,\n' +
    '          candidates: message.direct.candidates,\n' +
    '          leaseExpiresAt: device.expiresAt,\n' +
    '        });\n' +
    '        if (direct.candidates.length) {\n' +
    '          device.mesh.supportedPaths = [...new Set(["direct-udp", ...device.mesh.supportedPaths])];\n' +
    '          device.mesh.preferredPath = "direct-udp";\n' +
    '        }\n' +
    '        publishDirectPeerMaps(socket.accountId, options.directPaths);\n' +
    '      } // GBF-412 refresh direct candidates\n' +
    '      device.status = device.expiresAt > Date.now() ? "online" : "offline";\n',
  '// GBF-412 refresh direct candidates',
);

replaceOnce(
  '  if (message.type === "result") {\n',
  '  if (message.type === "direct_path_health") {\n' +
    '    if (!options.directPaths || !socket.registryKey) return;\n' +
    '    const reporter = devices.get(socket.registryKey);\n' +
    '    const targetId = String(message.targetDeviceId || "").trim();\n' +
    '    const target = devices.get(registryKey(socket.accountId, targetId));\n' +
    '    if (!reporter || reporter.socket !== socket || !target || target.central || !target.mesh) return;\n' +
    '    const accepted = options.directPaths.reportHealth({\n' +
    '      accountId: socket.accountId,\n' +
    '      deviceId: target.id,\n' +
    '      generation: target.generation,\n' +
    '      candidateId: String(message.candidateId || ""),\n' +
    '      reachable: message.reachable === true,\n' +
    '      latencyMs: Number(message.latencyMs) || 0,\n' +
    '      loss: Number(message.loss) || 0,\n' +
    '    });\n' +
    '    if (!accepted) return;\n' +
    '    const selected = options.directPaths.select(socket.accountId, target.id);\n' +
    '    const nextPath = selected.path === "direct-udp" ? "direct-udp" : "relay";\n' +
    '    if (target.mesh.activePath !== nextPath) target.mesh.pathChangedAt = Date.now();\n' +
    '    target.mesh.activePath = nextPath;\n' +
    '    publishDirectPeerMaps(socket.accountId, options.directPaths);\n' +
    '    audit(options, { type: "device.direct_path_health", accountId: socket.accountId, reporterDeviceId: reporter.id, targetDeviceId: target.id, activePath: nextPath, latencyMs: Number(message.latencyMs) || 0 });\n' +
    '    return;\n' +
    '  } // GBF-412 authenticated direct path health\n\n' +
    '  if (message.type === "result") {\n',
  '// GBF-412 authenticated direct path health',
);

replaceOnce(
  '  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_RESULT_BYTES });\n',
  '  const directPaths = options.directPaths ?? createDirectPathRegistry(); // GBF-412 direct path coordinator\n' +
    '  const gatewayOptions = { ...options, directPaths };\n' +
    '  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_RESULT_BYTES });\n',
  '// GBF-412 direct path coordinator',
);

replaceOnce(
  '        .then(() => handleAgentMessage(socket, raw, options))\n',
  '        .then(() => handleAgentMessage(socket, raw, gatewayOptions)) // GBF-412 direct-aware message handling\n',
  '// GBF-412 direct-aware message handling',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied direct path gateway rendezvous integration." : "Direct path gateway rendezvous integration already applied.");
