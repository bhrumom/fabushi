import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-agent.js");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing direct agent integration anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  '} from "./device-mesh.js"; // GBF-412 device mesh\n',
  '} from "./device-mesh.js"; // GBF-412 device mesh\n' +
    'import { bindDirectProbeEndpoint, collectHostUdpCandidates, discoverServerReflexiveCandidate } from "./device-direct-path.js"; // GBF-412 direct agent\n',
  '// GBF-412 direct agent',
);

replaceOnce(
  '    meshPosture: meshPostureFromEnvironment(env), // GBF-412 mesh config\n  };\n',
  '    meshPosture: meshPostureFromEnvironment(env), // GBF-412 mesh config\n' +
    '    directPath: {\n' +
    '      enabled: !/^(0|false|no)$/iu.test(String(env.FABUSHI_DIRECT_PATH_ENABLED ?? "1")),\n' +
    '      host: String(env.FABUSHI_DIRECT_BIND_HOST || "0.0.0.0"),\n' +
    '      port: Math.max(0, Math.min(65535, Number(env.FABUSHI_DIRECT_BIND_PORT) || 0)),\n' +
    '      stunHost: String(env.FABUSHI_STUN_HOST || "").trim(),\n' +
    '      stunPort: Math.max(1, Math.min(65535, Number(env.FABUSHI_STUN_PORT) || 3478)),\n' +
    '    }, // GBF-412 direct path config\n' +
    '  };\n',
  '// GBF-412 direct path config',
);

replaceOnce(
  '      const connectionGeneration = randomBytes(16).toString("hex");\n      const activeGatewayToken = config.getGatewayToken ? await config.getGatewayToken() : config.gatewayToken;\n',
  '      const connectionGeneration = randomBytes(16).toString("hex");\n' +
    '      const directPeers = new Map();\n' +
    '      let directEndpoint = null;\n' +
    '      let directCandidates = [];\n' +
    '      if (config.directPath?.enabled) {\n' +
    '        directEndpoint = await bindDirectProbeEndpoint({\n' +
    '          identity: meshIdentity,\n' +
    '          deviceId: config.deviceId,\n' +
    '          generation: connectionGeneration,\n' +
    '          host: config.directPath.host,\n' +
    '          port: config.directPath.port,\n' +
    '          expectedPeer: (peerDeviceId) => {\n' +
    '            const peer = directPeers.get(peerDeviceId);\n' +
    '            return peer ? { fromDeviceId: peer.deviceId, fromGeneration: peer.generation, nodeKeyFingerprint: peer.nodeKeyFingerprint } : null;\n' +
    '          },\n' +
    '        });\n' +
    '        directCandidates = collectHostUdpCandidates(directEndpoint.address.port);\n' +
    '        if (config.directPath.stunHost) {\n' +
    '          try {\n' +
    '            const srflx = await discoverServerReflexiveCandidate({ socket: directEndpoint.socket, stunHost: config.directPath.stunHost, stunPort: config.directPath.stunPort });\n' +
    '            if (srflx) directCandidates = [...directCandidates, srflx];\n' +
    '          } catch (error) {\n' +
    '            logError(`Fabushi STUN endpoint discovery failed; relay remains available: ${error instanceof Error ? error.message : String(error)}`);\n' +
    '          }\n' +
    '        }\n' +
    '      } // GBF-412 establish direct probe endpoint\n' +
    '      const activeGatewayToken = config.getGatewayToken ? await config.getGatewayToken() : config.gatewayToken;\n',
  '// GBF-412 establish direct probe endpoint',
);

replaceOnce(
  '          mesh, // GBF-412 signed node and relay path state\n        }));\n',
  '          mesh, // GBF-412 signed node and relay path state\n' +
    '          ...(directEndpoint ? { direct: { version: "fabushi.direct-path.v1", candidates: directCandidates } } : {}),\n' +
    '        })); // GBF-412 publish direct candidates\n',
  '// GBF-412 publish direct candidates',
);

replaceOnce(
  '            mesh: { activePath: "relay", posture: config.meshPosture ?? {} },\n          })); // GBF-412 mesh heartbeat\n',
  '            mesh: { activePath: "relay", posture: config.meshPosture ?? {} },\n' +
    '            ...(directEndpoint ? { direct: { version: "fabushi.direct-path.v1", candidates: directCandidates } } : {}),\n' +
    '          })); // GBF-412 mesh heartbeat and direct candidate refresh\n',
  '// GBF-412 mesh heartbeat and direct candidate refresh',
);

replaceOnce(
  '        if (message.type !== "call" || !message.requestId || !message.toolName) return;\n',
  '        if (message.type === "direct_peer_map") {\n' +
    '          if (!directEndpoint || message.version !== "fabushi.direct-path.v1" || !Array.isArray(message.peers)) return;\n' +
    '          directPeers.clear();\n' +
    '          for (const peer of message.peers.slice(0, 50)) {\n' +
    '            if (!peer?.deviceId || !peer?.generation || !peer?.nodeKeyFingerprint || !Array.isArray(peer.candidates)) continue;\n' +
    '            directPeers.set(String(peer.deviceId), peer);\n' +
    '          }\n' +
    '          for (const peer of directPeers.values()) {\n' +
    '            for (const candidate of peer.candidates.slice(0, 8)) {\n' +
    '              if (!candidate?.id || !candidate?.host || !candidate?.port) continue;\n' +
    '              const started = Date.now();\n' +
    '              directEndpoint.probe({ peer, candidate, timeoutMs: 1_500 })\n' +
    '                .then((result) => {\n' +
    '                  if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_path_health", targetDeviceId: peer.deviceId, candidateId: candidate.id, reachable: true, latencyMs: result.latencyMs, loss: 0 }));\n' +
    '                })\n' +
    '                .catch(() => {\n' +
    '                  if (socket.readyState === WebSocketImpl.OPEN) socket.send(JSON.stringify({ type: "direct_path_health", targetDeviceId: peer.deviceId, candidateId: candidate.id, reachable: false, latencyMs: Date.now() - started, loss: 1 }));\n' +
    '                });\n' +
    '            }\n' +
    '          }\n' +
    '          return;\n' +
    '        } // GBF-412 probe same-account peers\n' +
    '        if (message.type !== "call" || !message.requestId || !message.toolName) return;\n',
  '// GBF-412 probe same-account peers',
);

replaceOnce(
  '        if (activeSocket === socket) activeSocket = null;\n        if (stopped) return;\n',
  '        if (activeSocket === socket) activeSocket = null;\n' +
    '        if (directEndpoint) { try { directEndpoint.close(); } catch {} directEndpoint = null; } // GBF-412 close direct socket on reconnect\n' +
    '        if (stopped) return;\n',
  '// GBF-412 close direct socket on reconnect',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied desktop direct path agent integration." : "Desktop direct path agent integration already applied.");
