package com.ombhrum.fabushi

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.ombhrum.fabushi.core.MahayanaHost
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.io.Closeable
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.min

/**
 * Account-scoped Android device agent.
 *
 * The Fabushi access token proves the account boundary. A non-exportable
 * Android Keystore P-256 key independently signs every connection generation,
 * device id and tool schema. The only data path currently advertised is the
 * official TLS WebSocket relay; no direct/P2P claim is made.
 */
class FabushiDeviceMeshAgent(
    context: Context,
    private val surface: FabushiAppAgentSurface,
    private val gatewayUrl: String = OfficialGatewayUrl,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .pingInterval(25, TimeUnit.SECONDS)
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build(),
) : Closeable {
    companion object {
        const val ProtocolVersion = "fabushi.device-mesh.v1"
        const val OfficialGatewayUrl = "wss://fabushi-mcp.ombhrum.com/agent"
        private const val NodeKeyAlias = "fabushi-device-mesh-v1"
        private const val HeartbeatMilliseconds = 20_000L
        private const val MaximumReconnectMilliseconds = 30_000L
        private const val MaximumResultCharacters = 1_000_000

        val ToolNames = FabushiAppAgentSurface.ToolNames

        private val MeshFeatures = listOf(
            "account-scoped-discovery",
            "signed-node-identity",
            "lease-heartbeat",
            "relay-fallback",
            "path-observability",
            "capability-catalog",
        )
    }

    data class State(
        val running: Boolean,
        val connected: Boolean,
        val registered: Boolean,
        val deviceId: String?,
        val error: String?,
    )

    private data class AccountSession(
        val accessToken: String,
        val deviceId: String,
    )

    private val application = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val rustHost = MahayanaHost(application)
    private val random = SecureRandom()
    private val started = AtomicBoolean(false)
    private val stateLock = Any()
    private var state = State(false, false, false, null, null)
    private var reconnectAttempt = 0
    private var reconnectJob: Job? = null
    private var heartbeatJob: Job? = null
    @Volatile private var socket: WebSocket? = null
    @Volatile private var currentGeneration: String? = null

    fun state(): State = synchronized(stateLock) { state.copy() }

    fun start() {
        if (!started.compareAndSet(false, true)) return
        updateState { it.copy(running = true, error = null) }
        scheduleConnect(0)
    }

    override fun close() {
        if (!started.compareAndSet(true, false)) return
        reconnectJob?.cancel()
        heartbeatJob?.cancel()
        socket?.close(1000, "Fabushi Android device agent stopping")
        socket = null
        currentGeneration = null
        updateState { State(false, false, false, it.deviceId, null) }
        scope.cancel()
        rustHost.close()
        client.dispatcher.executorService.shutdown()
        client.connectionPool.evictAll()
    }

    private fun scheduleConnect(delayMilliseconds: Long) {
        if (!started.get()) return
        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            if (delayMilliseconds > 0) delay(delayMilliseconds)
            connectOnce()
        }
    }

    private fun connectOnce() {
        if (!started.get()) return
        val session = runCatching { accountSession() }.getOrElse { error ->
            updateState { it.copy(connected = false, registered = false, error = safeError(error)) }
            scheduleReconnect()
            return
        }
        val request = Request.Builder()
            .url(gatewayUrl)
            .header("Authorization", "Bearer ${session.accessToken}")
            .build()
        val listener = Listener(session)
        socket = client.newWebSocket(request, listener)
    }

    private fun scheduleReconnect() {
        if (!started.get()) return
        heartbeatJob?.cancel()
        heartbeatJob = null
        socket = null
        currentGeneration = null
        val exponent = min(reconnectAttempt, 6)
        val delayMilliseconds = min(1_000L shl exponent, MaximumReconnectMilliseconds)
        reconnectAttempt += 1
        scheduleConnect(delayMilliseconds)
    }

    private fun accountSession(): AccountSession {
        val result = rustHost.request("feature.auth.deviceAgentSession")
        val accessToken = result.optString("accessToken").trim()
        val rawDeviceId = result.optString("deviceId").trim()
        require(accessToken.length in 24..16_384 && accessToken.none(Char::isWhitespace)) {
            "Fabushi account does not have a valid device-agent access token"
        }
        require(rawDeviceId.matches(Regex("[A-Za-z0-9._:-]{1,128}"))) {
            "Fabushi account returned an invalid device id"
        }
        val suffix = "-android"
        val deviceId = if (rawDeviceId.endsWith(suffix)) rawDeviceId else rawDeviceId.take(128 - suffix.length) + suffix
        return AccountSession(accessToken = accessToken, deviceId = deviceId)
    }

    private inner class Listener(
        private val session: AccountSession,
    ) : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            reconnectAttempt = 0
            updateState { it.copy(connected = true, registered = false, deviceId = session.deviceId, error = null) }
            val generation = randomBytes(24).base64Url()
            currentGeneration = generation
            val catalog = toolCatalog()
            val schemaVersion = sha256(catalog.toString().toByteArray())
            val registration = signedRegistration(session.deviceId, generation, schemaVersion)
            registration.put("type", "register")
            registration.put("deviceId", session.deviceId)
            registration.put("name", "Fabushi on ${Build.MANUFACTURER} ${Build.MODEL}".take(200))
            registration.put("platform", "android")
            registration.put("generation", generation)
            registration.put("leaseSeconds", 14_400)
            registration.put("capabilities", JSONArray(ToolNames))
            registration.put("tools", catalog)
            registration.put("metadata", JSONObject()
                .put("kind", "fabushi-mobile")
                .put("runnerOs", "Android ${Build.VERSION.RELEASE}")
                .put("runnerArch", Build.SUPPORTED_ABIS.firstOrNull().orEmpty())
            )
            if (!webSocket.send(registration.toString())) {
                webSocket.close(1011, "registration send failed")
                return
            }
            startHeartbeat(webSocket)
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (text.length > MaximumResultCharacters) {
                webSocket.close(1009, "device message too large")
                return
            }
            val message = runCatching { JSONObject(text) }.getOrNull() ?: run {
                webSocket.close(1007, "invalid JSON")
                return
            }
            when (message.optString("type")) {
                "registered" -> updateState { it.copy(registered = true, error = null) }
                "call" -> handleCall(webSocket, message)
            }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(code, reason)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (socket === webSocket) {
                updateState { it.copy(connected = false, registered = false, error = null) }
                scheduleReconnect()
            }
        }

        override fun onFailure(webSocket: WebSocket, throwable: Throwable, response: Response?) {
            if (socket === webSocket) {
                updateState { it.copy(connected = false, registered = false, error = safeError(throwable)) }
                scheduleReconnect()
            }
        }
    }

    private fun startHeartbeat(webSocket: WebSocket) {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (started.get() && socket === webSocket) {
                delay(HeartbeatMilliseconds)
                val appState = if (surface.status().available) "foreground" else "background"
                val message = JSONObject()
                    .put("type", "heartbeat")
                    .put("at", System.currentTimeMillis())
                    .put("mesh", JSONObject()
                        .put("activePath", "relay")
                        .put("posture", posture(appState))
                    )
                if (!webSocket.send(message.toString())) break
            }
        }
    }

    private fun handleCall(webSocket: WebSocket, message: JSONObject) {
        val requestId = message.optString("requestId")
        val toolName = message.optString("toolName")
        val arguments = message.optJSONObject("arguments") ?: JSONObject()
        if (!requestId.matches(Regex("[A-Fa-f0-9]{16,64}")) || toolName !in ToolNames) return
        scope.launch {
            val response = runCatching {
                val result = withContext(Dispatchers.Main.immediate) { callSurface(toolName, arguments) }
                JSONObject()
                    .put("type", "result")
                    .put("requestId", requestId)
                    .put("ok", true)
                    .put("result", JSONObject()
                        .put("structuredContent", result)
                        .put("content", JSONArray().put(JSONObject()
                            .put("type", "text")
                            .put("text", summary(toolName, result))
                        ))
                    )
            }.getOrElse { error ->
                JSONObject()
                    .put("type", "result")
                    .put("requestId", requestId)
                    .put("ok", false)
                    .put("error", safeError(error))
            }
            webSocket.send(response.toString())
        }
    }

    private suspend fun callSurface(toolName: String, arguments: JSONObject): JSONObject = when (toolName) {
        FabushiAppAgentSurface.StatusTool -> statusJson(surface.status())
        FabushiAppAgentSurface.SnapshotTool -> {
            val maximum = arguments.optInt("maxElements", 500).coerceIn(1, 500)
            snapshotJson(surface.snapshot(), maximum)
        }
        FabushiAppAgentSurface.FindTool -> {
            val matches = surface.find(
                agentId = arguments.optionalString("agentId"),
                role = arguments.optionalString("role"),
                name = arguments.optionalString("name") ?: arguments.optionalString("text"),
                limit = arguments.optInt("limit", 25),
            )
            JSONObject().put("count", matches.size).put("matches", elementsJson(matches))
        }
        FabushiAppAgentSurface.ActionTool -> {
            val agentId = arguments.optionalString("agentId")
                ?: error("fabushi.app.action requires agentId on Android")
            val action = arguments.optString("action").takeIf(String::isNotBlank)
                ?: error("fabushi.app.action requires action")
            snapshotJson(surface.action(
                expectedGeneration = arguments.optLong("generation", -1),
                agentId = agentId,
                action = action,
                value = arguments.optionalString("value"),
            ))
        }
        FabushiAppAgentSurface.WaitTool -> assertionJson(surface.waitFor(
            expectedScreen = arguments.optionalString("screen"),
            agentId = arguments.optionalString("agentId"),
            role = arguments.optionalString("role"),
            name = arguments.optionalString("name") ?: arguments.optionalString("text"),
            state = arguments.optString("state", "present"),
            timeoutMilliseconds = arguments.optLong("timeoutMs", 10_000),
        ))
        FabushiAppAgentSurface.AssertTool -> assertionJson(surface.assertState(
            expectedScreen = arguments.optionalString("screen"),
            agentId = arguments.optionalString("agentId"),
            role = arguments.optionalString("role"),
            name = arguments.optionalString("name") ?: arguments.optionalString("text"),
            state = arguments.optString("state", "present"),
        ))
        else -> error("unsupported Fabushi App MCP tool")
    }

    private fun signedRegistration(deviceId: String, generation: String, toolSchemaVersion: String): JSONObject {
        val keyPair = loadOrCreateNodeKey()
        val publicKey = keyPair.public as ECPublicKey
        val jwk = JSONObject()
            .put("kty", "EC")
            .put("crv", "P-256")
            .put("x", coordinate(publicKey.w.affineX).base64Url())
            .put("y", coordinate(publicKey.w.affineY).base64Url())
        val nonce = randomBytes(24).base64Url()
        val canonicalKey = "EC:P-256:${jwk.getString("x")}:${jwk.getString("y")}"
        val payload = listOf(
            ProtocolVersion,
            deviceId,
            generation,
            toolSchemaVersion,
            nonce,
            canonicalKey,
        ).joinToString("\n")
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(keyPair.private)
        signer.update(payload.toByteArray(Charsets.UTF_8))
        val signature = signer.sign().base64Url()
        return JSONObject().put("mesh", JSONObject()
            .put("protocolVersion", ProtocolVersion)
            .put("nodePublicKey", jwk)
            .put("nonce", nonce)
            .put("signature", signature)
            .put("features", JSONArray(MeshFeatures))
            .put("supportedPaths", JSONArray().put("relay"))
            .put("preferredPath", "relay")
            .put("activePath", "relay")
            .put("tags", JSONArray().put("client:fabushi").put("platform:android").put("role:mobile"))
            .put("posture", posture("foreground"))
        )
    }

    private fun toolCatalog(): JSONArray {
        fun descriptor(name: String, description: String, properties: JSONObject = JSONObject()): JSONObject = JSONObject()
            .put("name", name)
            .put("title", name)
            .put("description", description)
            .put("inputSchema", JSONObject()
                .put("type", "object")
                .put("properties", properties)
                .put("additionalProperties", false)
            )
            .put("annotations", JSONObject()
                .put("readOnlyHint", name != FabushiAppAgentSurface.ActionTool)
                .put("destructiveHint", name == FabushiAppAgentSurface.ActionTool)
                .put("idempotentHint", name != FabushiAppAgentSurface.ActionTool)
                .put("openWorldHint", false)
            )

        val query = JSONObject()
            .put("agentId", JSONObject().put("type", "string"))
            .put("role", JSONObject().put("type", "string"))
            .put("name", JSONObject().put("type", "string"))
            .put("text", JSONObject().put("type", "string"))
            .put("state", JSONObject().put("type", "string"))
            .put("screen", JSONObject().put("type", "string"))
        return JSONArray()
            .put(descriptor(FabushiAppAgentSurface.StatusTool, "Read Android Fabushi App MCP availability."))
            .put(descriptor(FabushiAppAgentSurface.SnapshotTool, "Read the redacted Android Fabushi semantic surface.", JSONObject()
                .put("maxElements", JSONObject().put("type", "integer").put("minimum", 1).put("maximum", 500))))
            .put(descriptor(FabushiAppAgentSurface.FindTool, "Find Android Fabushi semantic elements.", JSONObject(query.toString())
                .put("limit", JSONObject().put("type", "integer").put("minimum", 1).put("maximum", 100))))
            .put(descriptor(FabushiAppAgentSurface.ActionTool, "Invoke a generation-bound Android Fabushi semantic action.", JSONObject()
                .put("generation", JSONObject().put("type", "integer"))
                .put("agentId", JSONObject().put("type", "string"))
                .put("action", JSONObject().put("type", "string"))
                .put("value", JSONObject().put("type", "string"))))
            .put(descriptor(FabushiAppAgentSurface.WaitTool, "Wait for an Android Fabushi semantic condition.", JSONObject(query.toString())
                .put("timeoutMs", JSONObject().put("type", "integer").put("minimum", 100).put("maximum", 30_000))))
            .put(descriptor(FabushiAppAgentSurface.AssertTool, "Assert an Android Fabushi semantic condition.", query))
    }

    private fun posture(appState: String): JSONObject = JSONObject()
        .put("appVersion", BuildConfig.VERSION_NAME)
        .put("buildNumber", BuildConfig.VERSION_CODE.toString())
        .put("deviceClass", "phone-tablet")
        .put("deviceModel", "${Build.MANUFACTURER} ${Build.MODEL}".take(240))
        .put("osVersion", "Android ${Build.VERSION.RELEASE}".take(240))
        .put("appState", appState)

    private fun loadOrCreateNodeKey(): KeyPair {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existingPrivate = keyStore.getKey(NodeKeyAlias, null) as? java.security.PrivateKey
        val existingPublic = keyStore.getCertificate(NodeKeyAlias)?.publicKey
        if (existingPrivate != null && existingPublic is ECPublicKey) return KeyPair(existingPublic, existingPrivate)
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        val specification = KeyGenParameterSpec.Builder(NodeKeyAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .build()
        generator.initialize(specification)
        return generator.generateKeyPair()
    }

    private fun updateState(transform: (State) -> State) = synchronized(stateLock) {
        state = transform(state)
    }

    private fun randomBytes(count: Int) = ByteArray(count).also(random::nextBytes)

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { "%02x".format(it) }

    private fun coordinate(value: BigInteger): ByteArray {
        val bytes = value.toByteArray()
        return when {
            bytes.size == 32 -> bytes
            bytes.size == 33 && bytes[0] == 0.toByte() -> bytes.copyOfRange(1, 33)
            bytes.size < 32 -> ByteArray(32 - bytes.size) + bytes
            else -> bytes.copyOfRange(bytes.size - 32, bytes.size)
        }
    }

    private fun ByteArray.base64Url(): String = Base64.encodeToString(
        this,
        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
    )

    private fun JSONObject.optionalString(key: String): String? = optString(key)
        .trim()
        .takeIf(String::isNotBlank)

    private fun statusJson(value: FabushiAppAgentSurface.Status) = JSONObject()
        .put("version", value.version)
        .put("appId", value.appId)
        .put("platform", value.platform)
        .put("available", value.available)
        .put("screen", value.screen)
        .put("generation", value.generation)

    private fun snapshotJson(value: FabushiAppAgentSurface.Snapshot, maximum: Int = 500) = JSONObject()
        .put("version", value.version)
        .put("appId", value.appId)
        .put("platform", value.platform)
        .put("screen", value.screen)
        .put("generation", value.generation)
        .put("elementCount", value.elements.size)
        .put("elements", elementsJson(value.elements.take(maximum.coerceIn(1, 500))))

    private fun assertionJson(value: FabushiAppAgentSurface.Assertion) = JSONObject()
        .put("passed", value.passed)
        .put("screen", value.screen)
        .put("generation", value.generation)
        .put("matches", elementsJson(value.matches))
        .put("failures", JSONArray(value.failures))

    private fun elementsJson(elements: List<FabushiAppAgentSurface.Element>): JSONArray = JSONArray().also { array ->
        elements.forEach { element ->
            array.put(JSONObject()
                .put("agentId", element.agentId)
                .put("role", element.role)
                .put("name", element.name)
                .put("visible", element.visible)
                .put("enabled", element.enabled)
                .put("sensitive", element.sensitive)
                .apply {
                    element.valuePresent?.let { put("valuePresent", it) }
                    element.valueLength?.let { put("valueLength", it) }
                }
            )
        }
    }

    private fun summary(toolName: String, result: JSONObject): String = when (toolName) {
        FabushiAppAgentSurface.StatusTool -> "Android Fabushi App MCP availability: ${result.optBoolean("available")}."
        FabushiAppAgentSurface.SnapshotTool -> "Read Android Fabushi semantic surface generation ${result.optLong("generation")}."
        FabushiAppAgentSurface.FindTool -> "Found ${result.optInt("count")} Android Fabushi semantic elements."
        FabushiAppAgentSurface.ActionTool -> "Completed Android Fabushi semantic action."
        FabushiAppAgentSurface.WaitTool -> "Android Fabushi semantic wait passed=${result.optBoolean("passed")}."
        else -> "Android Fabushi semantic assertion passed=${result.optBoolean("passed")}."
    }

    private fun safeError(error: Throwable): String = (error.message ?: error::class.java.simpleName)
        .replace(Regex("(?i)(bearer|token|password|secret)\\s*[:=]?\\s*[^\\s,;]+"), "$1=<redacted>")
        .take(500)
}
