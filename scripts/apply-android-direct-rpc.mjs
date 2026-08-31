import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiDeviceMeshAgent.kt");
let source = readFileSync(path, "utf8");
let changed = false;
function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing Android direct RPC anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  'import java.util.concurrent.TimeUnit\n',
  'import java.util.concurrent.TimeUnit\nimport java.util.concurrent.ConcurrentHashMap // GBF-412 Android invocation dedupe\n',
  '// GBF-412 Android invocation dedupe',
);

replaceOnce(
  '    @Volatile private var directPath: FabushiDeviceDirectPath? = null // GBF-412 Android direct path\n',
  '    @Volatile private var directPath: FabushiDeviceDirectPath? = null // GBF-412 Android direct path\n' +
    '    private val invocationResults = ConcurrentHashMap<String, CompletableDeferred<JSONObject>>() // GBF-412 Android exactly-once calls\n',
  '// GBF-412 Android exactly-once calls',
);

replaceOnce(
  '                "direct_peer_map" -> {\n                    val direct = directPath ?: return\n                    if (message.optString("version") != FabushiDeviceDirectPath.ProtocolVersion) return\n                    direct.updatePeers(message.optJSONArray("peers"))\n',
  '                "direct_peer_map" -> {\n' +
    '                    val direct = directPath ?: return\n' +
    '                    if (message.optString("version") != FabushiDeviceDirectPath.ProtocolVersion) return\n' +
    '                    direct.updatePeers(message.optJSONArray("peers"))\n' +
    '                    direct.configureRpc(message.optString("accountBinding")) { invocationId, toolName, arguments ->\n' +
    '                        executeInvocation(invocationId, toolName, arguments)\n' +
    '                    } // GBF-412 Android account-bound direct RPC\n',
  '// GBF-412 Android account-bound direct RPC',
);

replaceOnce(
  '                "call" -> handleCall(webSocket, message)\n',
  '                "direct_forward_call" -> handleDirectForward(webSocket, message) // GBF-412 Android direct forwarding\n' +
    '                "call" -> handleCall(webSocket, message)\n',
  '// GBF-412 Android direct forwarding',
);

replaceOnce(
  '    private fun handleCall(webSocket: WebSocket, message: JSONObject) {\n',
  '    private fun handleDirectForward(webSocket: WebSocket, message: JSONObject) {\n' +
    '        val requestId = message.optString("requestId").take(128)\n' +
    '        val invocationId = message.optString("invocationId", requestId).take(128)\n' +
    '        val targetDeviceId = message.optString("targetDeviceId").take(128)\n' +
    '        val targetGeneration = message.optString("targetGeneration").take(128)\n' +
    '        val toolName = message.optString("toolName").take(128)\n' +
    '        val arguments = message.optJSONObject("arguments") ?: JSONObject()\n' +
    '        val direct = directPath\n' +
    '        val peer = direct?.peer(targetDeviceId)\n' +
    '        val candidate = peer?.let(direct::preferredCandidate)\n' +
    '        if (direct == null || peer == null || candidate == null || peer.generation != targetGeneration) {\n' +
    '            webSocket.send(JSONObject().put("type", "direct_forward_failed").put("requestId", requestId).put("invocationId", invocationId).put("error", "No authenticated Android direct route is available.").toString())\n' +
    '            return\n' +
    '        }\n' +
    '        scope.launch {\n' +
    '            runCatching { direct.call(peer, candidate, toolName, arguments, invocationId, message.optLong("timeoutMs", 2_500)) }\n' +
    '                .onSuccess { payload ->\n' +
    '                    if (payload.optString("kind") == "error" || !payload.optBoolean("ok", true)) {\n' +
    '                        webSocket.send(JSONObject().put("type", "direct_forward_failed").put("requestId", requestId).put("invocationId", invocationId).put("error", payload.optString("error", "direct call failed")).toString())\n' +
    '                    } else {\n' +
    '                        webSocket.send(JSONObject().put("type", "result").put("requestId", requestId).put("invocationId", invocationId).put("ok", true).put("route", "direct-udp").put("result", payload.optJSONObject("result") ?: JSONObject()).toString())\n' +
    '                    }\n' +
    '                }\n' +
    '                .onFailure { error ->\n' +
    '                    webSocket.send(JSONObject().put("type", "direct_forward_failed").put("requestId", requestId).put("invocationId", invocationId).put("error", safeError(error)).toString())\n' +
    '                }\n' +
    '        }\n' +
    '    } // GBF-412 Android peer direct call path\n\n' +
    '    private suspend fun executeInvocation(invocationId: String, toolName: String, arguments: JSONObject): JSONObject {\n' +
    '        require(invocationId.matches(Regex("[A-Za-z0-9._:-]{16,128}"))) { "invalid invocation id" }\n' +
    '        require(toolName in ToolNames) { "unsupported Fabushi App MCP tool" }\n' +
    '        val created = CompletableDeferred<JSONObject>()\n' +
    '        val existing = invocationResults.putIfAbsent(invocationId, created)\n' +
    '        if (existing != null) return existing.await()\n' +
    '        try {\n' +
    '            val structured = withContext(Dispatchers.Main.immediate) { callSurface(toolName, arguments) }\n' +
    '            val result = JSONObject().put("structuredContent", structured).put("content", JSONArray().put(JSONObject().put("type", "text").put("text", summary(toolName, structured))))\n' +
    '            created.complete(result)\n' +
    '            if (invocationResults.size > 512) invocationResults.entries.firstOrNull { it.value.isCompleted && it.key != invocationId }?.let { invocationResults.remove(it.key, it.value) }\n' +
    '            return result\n' +
    '        } catch (error: Throwable) {\n' +
    '            created.completeExceptionally(error)\n' +
    '            throw error\n' +
    '        }\n' +
    '    } // GBF-412 Android exactly-once execution boundary\n\n' +
    '    private fun handleCall(webSocket: WebSocket, message: JSONObject) {\n',
  '// GBF-412 Android peer direct call path',
);

replaceOnce(
  '        val requestId = message.optString("requestId")\n        val toolName = message.optString("toolName")\n',
  '        val requestId = message.optString("requestId")\n' +
    '        val invocationId = message.optString("invocationId", requestId).take(128) // GBF-412 Android relay invocation id\n' +
    '        val toolName = message.optString("toolName")\n',
  '// GBF-412 Android relay invocation id',
);

replaceOnce(
  '                val result = withContext(Dispatchers.Main.immediate) { callSurface(toolName, arguments) }\n                JSONObject()\n                    .put("type", "result")\n                    .put("requestId", requestId)\n                    .put("ok", true)\n                    .put("result", JSONObject()\n                        .put("structuredContent", result)\n                        .put("content", JSONArray().put(JSONObject()\n                            .put("type", "text")\n                            .put("text", summary(toolName, result))\n                        ))\n                    )\n',
  '                val result = executeInvocation(invocationId, toolName, arguments)\n' +
    '                JSONObject()\n' +
    '                    .put("type", "result")\n' +
    '                    .put("requestId", requestId)\n' +
    '                    .put("invocationId", invocationId)\n' +
    '                    .put("ok", true)\n' +
    '                    .put("result", result) // GBF-412 Android relay shares direct dedupe\n',
  '// GBF-412 Android relay shares direct dedupe',
);

replaceOnce(
  '                    .put("requestId", requestId)\n                    .put("ok", false)\n                    .put("error", safeError(error))\n',
  '                    .put("requestId", requestId)\n' +
    '                    .put("invocationId", invocationId)\n' +
    '                    .put("ok", false)\n' +
    '                    .put("error", safeError(error)) // GBF-412 Android failed invocation echo\n',
  '// GBF-412 Android failed invocation echo',
);

replaceOnce(
  '        val specification = KeyGenParameterSpec.Builder(NodeKeyAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)\n',
  '        val keyPurposes = KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY or\n' +
    '            (if (Build.VERSION.SDK_INT >= 31) KeyProperties.PURPOSE_AGREE_KEY else 0) // GBF-412 Android ECDH-capable fresh keys\n' +
    '        val specification = KeyGenParameterSpec.Builder(NodeKeyAlias, keyPurposes)\n',
  '// GBF-412 Android ECDH-capable fresh keys',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied Android encrypted direct RPC integration." : "Android encrypted direct RPC integration already applied.");
