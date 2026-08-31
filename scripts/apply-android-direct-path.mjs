import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiDeviceMeshAgent.kt");
let source = readFileSync(path, "utf8");
let changed = false;
function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing Android direct path anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  '    @Volatile private var currentGeneration: String? = null\n',
  '    @Volatile private var currentGeneration: String? = null\n    @Volatile private var directPath: FabushiDeviceDirectPath? = null // GBF-412 Android direct path\n',
  '// GBF-412 Android direct path',
);

replaceOnce(
  '        socket = null\n        currentGeneration = null\n        updateState { State(false, false, false, it.deviceId, null) }\n',
  '        socket = null\n        currentGeneration = null\n        directPath?.close()\n        directPath = null // GBF-412 Android direct shutdown\n        updateState { State(false, false, false, it.deviceId, null) }\n',
  '// GBF-412 Android direct shutdown',
);

replaceOnce(
  '        socket = null\n        currentGeneration = null\n        val exponent = min(reconnectAttempt, 6)\n',
  '        socket = null\n        currentGeneration = null\n        directPath?.close()\n        directPath = null // GBF-412 Android direct reconnect cleanup\n        val exponent = min(reconnectAttempt, 6)\n',
  '// GBF-412 Android direct reconnect cleanup',
);

replaceOnce(
  '            currentGeneration = generation\n            val catalog = toolCatalog()\n',
  '            currentGeneration = generation\n' +
    '            directPath?.close()\n' +
    '            directPath = runCatching {\n' +
    '                FabushiDeviceDirectPath(session.deviceId, generation, loadOrCreateNodeKey(), scope).also { it.start() }\n' +
    '            }.getOrNull() // GBF-412 Android direct endpoint start\n' +
    '            val catalog = toolCatalog()\n',
  '// GBF-412 Android direct endpoint start',
);

replaceOnce(
  '            registration.put("metadata", JSONObject()\n                .put("kind", "fabushi-mobile")\n                .put("runnerOs", "Android ${Build.VERSION.RELEASE}")\n                .put("runnerArch", Build.SUPPORTED_ABIS.firstOrNull().orEmpty())\n            )\n',
  '            registration.put("metadata", JSONObject()\n' +
    '                .put("kind", "fabushi-mobile")\n' +
    '                .put("runnerOs", "Android ${Build.VERSION.RELEASE}")\n' +
    '                .put("runnerArch", Build.SUPPORTED_ABIS.firstOrNull().orEmpty())\n' +
    '            )\n' +
    '            directPath?.let { direct ->\n' +
    '                registration.put("direct", direct.registrationJson())\n' +
    '                registration.getJSONObject("mesh")\n' +
    '                    .put("supportedPaths", JSONArray().put("direct-udp").put("relay"))\n' +
    '                    .put("preferredPath", "direct-udp")\n' +
    '            } // GBF-412 Android publish direct candidates\n',
  '// GBF-412 Android publish direct candidates',
);

replaceOnce(
  '            when (message.optString("type")) {\n                "registered" -> updateState { it.copy(registered = true, error = null) }\n                "call" -> handleCall(webSocket, message)\n            }\n',
  '            when (message.optString("type")) {\n' +
    '                "registered" -> updateState { it.copy(registered = true, error = null) }\n' +
    '                "direct_peer_map" -> {\n' +
    '                    val direct = directPath ?: return\n' +
    '                    if (message.optString("version") != FabushiDeviceDirectPath.ProtocolVersion) return\n' +
    '                    direct.updatePeers(message.optJSONArray("peers"))\n' +
    '                    direct.probeAll { health ->\n' +
    '                        val report = JSONObject()\n' +
    '                            .put("type", "direct_path_health")\n' +
    '                            .put("targetDeviceId", health.targetDeviceId)\n' +
    '                            .put("candidateId", health.candidateId)\n' +
    '                            .put("reachable", health.reachable)\n' +
    '                            .put("latencyMs", health.latencyMs)\n' +
    '                            .put("loss", health.loss)\n' +
    '                        if (socket === webSocket) webSocket.send(report.toString())\n' +
    '                    }\n' +
    '                } // GBF-412 Android direct peer probing\n' +
    '                "call" -> handleCall(webSocket, message)\n' +
    '            }\n',
  '// GBF-412 Android direct peer probing',
);

replaceOnce(
  '                val message = JSONObject()\n                    .put("type", "heartbeat")\n                    .put("at", System.currentTimeMillis())\n                    .put("mesh", JSONObject()\n                        .put("activePath", "relay")\n                        .put("posture", posture(appState))\n                    )\n',
  '                val message = JSONObject()\n' +
    '                    .put("type", "heartbeat")\n' +
    '                    .put("at", System.currentTimeMillis())\n' +
    '                    .put("mesh", JSONObject()\n' +
    '                        .put("activePath", "relay")\n' +
    '                        .put("posture", posture(appState))\n' +
    '                    )\n' +
    '                directPath?.let { message.put("direct", it.heartbeatJson()) } // GBF-412 Android direct heartbeat\n',
  '// GBF-412 Android direct heartbeat',
);

if (changed) writeFileSync(path, source);
await import("./apply-android-direct-rpc.mjs");
console.log(changed ? "Applied Android direct path integration." : "Android direct path integration already applied.");
