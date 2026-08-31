package com.ombhrum.fabushi

import android.util.Base64
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.json.JSONArray
import org.json.JSONObject
import java.io.Closeable
import java.math.BigInteger
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.NetworkInterface
import java.security.KeyFactory
import java.security.KeyPair
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/** Authenticated UDP path discovery and encrypted peer RPC for the Fabushi account mesh.
 * Relay remains the official reliability fallback whenever direct connectivity or
 * platform key agreement is unavailable.
 */
class FabushiDeviceDirectPath(
    private val deviceId: String,
    private val generation: String,
    private val keyPair: KeyPair,
    private val scope: CoroutineScope,
) : Closeable {
    companion object {
        const val ProtocolVersion = "fabushi.direct-path.v1"
        const val RpcProtocolVersion = "fabushi.direct-rpc.v1"
        private const val RpcPacketType = "fabushi-direct-rpc"
        private const val MaximumPacketBytes = 60 * 1024
        private const val ProbeTimeoutMilliseconds = 1_500L
        private const val RpcTimeoutMilliseconds = 2_500L
        private const val ReplayWindow = 128L
    }

    data class Candidate(val id: String, val host: String, val port: Int, val priority: Int, val scope: String)
    data class Peer(val deviceId: String, val generation: String, val fingerprint: String, val candidates: List<Candidate>)
    data class Health(val targetDeviceId: String, val candidateId: String, val reachable: Boolean, val latencyMs: Long, val loss: Double)

    private data class PendingProbe(val sentAt: Long, val deferred: CompletableDeferred<Long>)
    private data class PendingRpc(val deferred: CompletableDeferred<JSONObject>)
    private data class Session(
        val peer: Peer,
        val key: ByteArray,
        val sessionId: String,
        val peersJson: JSONArray,
        @Volatile var address: InetAddress,
        @Volatile var port: Int,
        @Volatile var sendSequence: Long = 0,
        @Volatile var highestReceived: Long = -1,
        val received: MutableSet<Long> = mutableSetOf(),
    )

    private val random = SecureRandom()
    private val running = AtomicBoolean(false)
    private val socket = DatagramSocket(0)
    private val peers = ConcurrentHashMap<String, Peer>()
    private val pendingProbes = ConcurrentHashMap<String, PendingProbe>()
    private val pendingRpc = ConcurrentHashMap<String, PendingRpc>()
    private val sessions = ConcurrentHashMap<String, Session>()
    private var receiveJob: Job? = null
    private val publicJwk = publicJwk(keyPair.public as ECPublicKey)
    private val fingerprint = fingerprint(publicJwk)
    @Volatile private var accountBinding: String? = null
    @Volatile private var rpcExecutor: (suspend (String, String, JSONObject) -> JSONObject)? = null

    fun configureRpc(binding: String?, executor: suspend (String, String, JSONObject) -> JSONObject) {
        val normalized = binding?.trim()?.take(128).orEmpty()
        if (normalized.length < 16) {
            accountBinding = null
            sessions.clear()
            rpcExecutor = executor
            return
        }
        if (accountBinding != normalized) sessions.clear()
        accountBinding = normalized
        rpcExecutor = executor
    }

    fun start() {
        if (!running.compareAndSet(false, true)) return
        receiveJob = scope.launch(Dispatchers.IO) {
            val bytes = ByteArray(MaximumPacketBytes)
            while (running.get() && !socket.isClosed) {
                try {
                    val packet = DatagramPacket(bytes, bytes.size)
                    socket.receive(packet)
                    handlePacket(bytes.copyOf(packet.length), packet.address, packet.port)
                } catch (_: Throwable) {
                    if (!running.get() || socket.isClosed) break
                }
            }
        }
    }

    fun candidates(): List<Candidate> {
        val results = mutableListOf<Candidate>()
        val interfaces = runCatching { Collections.list(NetworkInterface.getNetworkInterfaces()) }.getOrDefault(emptyList())
        for (network in interfaces) {
            if (!runCatching { network.isUp && !network.isLoopback }.getOrDefault(false)) continue
            for (address in Collections.list(network.inetAddresses)) {
                if (address.isLoopbackAddress || address.isAnyLocalAddress || address.isMulticastAddress) continue
                if (address !is Inet4Address && address !is Inet6Address) continue
                val host = address.hostAddress?.substringBefore('%') ?: continue
                results += Candidate("udp:host:$host:${socket.localPort}", host, socket.localPort, if (address is Inet4Address) 200 else 180, "host")
            }
        }
        return results.distinctBy(Candidate::id).take(24)
    }

    fun registrationJson(): JSONObject = JSONObject().put("version", ProtocolVersion).put("candidates", candidatesJson())
    fun heartbeatJson(): JSONObject = registrationJson()

    fun updatePeers(array: JSONArray?) {
        val updated = mutableMapOf<String, Peer>()
        if (array != null) {
            for (index in 0 until minOf(array.length(), 50)) {
                val raw = array.optJSONObject(index) ?: continue
                val peerId = raw.optString("deviceId").trim()
                val peerGeneration = raw.optString("generation").trim()
                val peerFingerprint = raw.optString("nodeKeyFingerprint").trim()
                if (peerId.isEmpty() || peerGeneration.isEmpty() || peerFingerprint.isEmpty()) continue
                val candidatesArray = raw.optJSONArray("candidates") ?: JSONArray()
                val peerCandidates = mutableListOf<Candidate>()
                for (candidateIndex in 0 until minOf(candidatesArray.length(), 24)) {
                    val candidate = candidatesArray.optJSONObject(candidateIndex) ?: continue
                    val host = candidate.optString("host").trim().substringBefore('%')
                    val port = candidate.optInt("port")
                    val id = candidate.optString("id").trim()
                    val candidateScope = candidate.optString("scope", "host")
                    if (id.isEmpty() || host.isEmpty() || port !in 1..65535 || candidateScope !in setOf("host", "srflx")) continue
                    peerCandidates += Candidate(id, host, port, candidate.optInt("priority", 100), candidateScope)
                }
                updated[peerId] = Peer(peerId, peerGeneration, peerFingerprint, peerCandidates)
            }
        }
        peers.clear()
        peers.putAll(updated)
        sessions.keys.removeIf { key -> updated[key]?.generation != sessions[key]?.peer?.generation }
    }

    fun peer(deviceId: String): Peer? = peers[deviceId]

    fun preferredCandidate(peer: Peer): Candidate? = peer.candidates.firstOrNull { candidate ->
        candidate.scope == "host" || candidate.scope == "srflx"
    }

    fun probeAll(report: (Health) -> Unit) {
        for (peer in peers.values) {
            for (candidate in peer.candidates.take(8)) {
                scope.launch(Dispatchers.IO) {
                    val startedAt = System.currentTimeMillis()
                    val latency = runCatching { probe(peer, candidate) }.getOrNull()
                    report(Health(peer.deviceId, candidate.id, latency != null, latency ?: (System.currentTimeMillis() - startedAt), if (latency == null) 1.0 else 0.0))
                }
            }
        }
    }

    suspend fun call(
        peer: Peer,
        candidate: Candidate,
        toolName: String,
        arguments: JSONObject,
        invocationId: String,
        timeoutMilliseconds: Long = RpcTimeoutMilliseconds,
    ): JSONObject = withContext(Dispatchers.IO) {
        require(invocationId.matches(Regex("[A-Za-z0-9._:-]{16,128}"))) { "invalid direct invocation id" }
        require(toolName.matches(Regex("[A-Za-z0-9._-]{1,128}"))) { "invalid direct tool name" }
        if (sessions[peer.deviceId]?.peer?.generation != peer.generation) probe(peer, candidate)
        val session = sessions[peer.deviceId] ?: error("authenticated direct session unavailable")
        val payload = JSONObject()
            .put("protocolVersion", RpcProtocolVersion)
            .put("kind", "call")
            .put("invocationId", invocationId)
            .put("toolName", toolName)
            .put("arguments", arguments)
            .put("fromDeviceId", deviceId)
            .put("toDeviceId", peer.deviceId)
            .put("sessionId", session.sessionId)
        val deferred = CompletableDeferred<JSONObject>()
        pendingRpc[invocationId] = PendingRpc(deferred)
        try {
            sendRpc(session, payload, candidate.host, candidate.port)
            withTimeout(timeoutMilliseconds.coerceIn(500, 5_000)) { deferred.await() }
        } finally {
            pendingRpc.remove(invocationId)
        }
    }

    private suspend fun probe(peer: Peer, candidate: Candidate): Long = withContext(Dispatchers.IO) {
        val nonce = randomBytes(18).base64Url()
        val packet = signedPacket("probe", peer.deviceId, nonce)
        val deferred = CompletableDeferred<Long>()
        pendingProbes[nonce] = PendingProbe(System.currentTimeMillis(), deferred)
        try {
            sendJson(packet, InetAddress.getByName(candidate.host), candidate.port)
            withTimeout(ProbeTimeoutMilliseconds) { deferred.await() }
        } finally {
            pendingProbes.remove(nonce)
        }
    }

    private fun handlePacket(bytes: ByteArray, address: InetAddress, port: Int) {
        if (bytes.size > MaximumPacketBytes) return
        val packet = runCatching { JSONObject(bytes.toString(Charsets.UTF_8)) }.getOrNull() ?: return
        val fromDeviceId = packet.optString("fromDeviceId")
        val peer = peers[fromDeviceId] ?: return
        when (packet.optString("type")) {
            "probe", "probe-ack" -> {
                if (!verifyPacket(packet, peer)) return
                establishSession(packet, peer, address, port)
                if (packet.optString("type") == "probe") {
                    runCatching { sendJson(signedPacket("probe-ack", peer.deviceId, packet.optString("nonce")), address, port) }
                } else {
                    val nonce = packet.optString("nonce")
                    val request = pendingProbes.remove(nonce) ?: return
                    request.deferred.complete((System.currentTimeMillis() - request.sentAt).coerceAtLeast(0))
                }
            }
            RpcPacketType -> handleRpcPacket(packet, peer, address, port)
        }
    }

    private fun establishSession(packet: JSONObject, peer: Peer, address: InetAddress, port: Int) {
        val binding = accountBinding ?: return
        val jwk = packet.optJSONObject("nodePublicKey") ?: return
        runCatching {
            val peerKey = ecPublicKey(jwk)
            val agreement = KeyAgreement.getInstance("ECDH")
            agreement.init(keyPair.private)
            agreement.doPhase(peerKey, true)
            val shared = agreement.generateSecret()
            val peersJson = rpcPeers(peer)
            val sessionBinding = JSONObject().put("protocolVersion", RpcProtocolVersion).put("accountId", binding).put("peers", peersJson)
            val sessionId = MessageDigest.getInstance("SHA-256").digest(canonicalJson(sessionBinding).toByteArray(Charsets.UTF_8)).base64Url().take(32)
            val key = hkdf(shared, ProtocolVersion.toByteArray(Charsets.UTF_8), canonicalJson(sessionBinding).toByteArray(Charsets.UTF_8), 32)
            sessions[peer.deviceId] = Session(peer, key, sessionId, peersJson, address, port)
        }
    }

    private fun handleRpcPacket(packet: JSONObject, peer: Peer, address: InetAddress, port: Int) {
        if (packet.optString("protocolVersion") != ProtocolVersion || packet.optString("toDeviceId") != deviceId || packet.optString("fromGeneration") != peer.generation) return
        val session = sessions[peer.deviceId] ?: return
        if (packet.optString("sessionId") != session.sessionId) return
        val envelope = packet.optJSONObject("envelope") ?: return
        val payload = runCatching { openEnvelope(session, envelope) }.getOrNull() ?: return
        session.address = address
        session.port = port
        when (payload.optString("kind")) {
            "call" -> {
                val executor = rpcExecutor ?: return
                val invocationId = payload.optString("invocationId")
                val toolName = payload.optString("toolName")
                val arguments = payload.optJSONObject("arguments") ?: JSONObject()
                scope.launch {
                    val responsePayload = runCatching { executor(invocationId, toolName, arguments) }
                        .fold(
                            onSuccess = { result -> JSONObject().put("protocolVersion", RpcProtocolVersion).put("kind", "result").put("invocationId", invocationId).put("ok", true).put("result", result) },
                            onFailure = { error -> JSONObject().put("protocolVersion", RpcProtocolVersion).put("kind", "error").put("invocationId", invocationId).put("ok", false).put("error", (error.message ?: error::class.java.simpleName).take(4_000)) },
                        )
                    responsePayload.put("fromDeviceId", deviceId).put("toDeviceId", peer.deviceId).put("sessionId", session.sessionId)
                    runCatching { sendRpc(session, responsePayload, address.hostAddress ?: return@launch, port) }
                }
            }
            "result", "error" -> {
                val invocationId = payload.optString("invocationId")
                pendingRpc[invocationId]?.deferred?.complete(payload)
            }
        }
    }

    private fun sendRpc(session: Session, payload: JSONObject, host: String, port: Int) {
        val sequence = synchronized(session) { session.sendSequence++ }
        val envelope = sealEnvelope(session, sequence, payload)
        val outer = JSONObject()
            .put("protocolVersion", ProtocolVersion)
            .put("type", RpcPacketType)
            .put("fromDeviceId", deviceId)
            .put("fromGeneration", generation)
            .put("toDeviceId", session.peer.deviceId)
            .put("sessionId", session.sessionId)
            .put("envelope", envelope)
        sendJson(outer, InetAddress.getByName(host), port)
    }

    private fun sealEnvelope(session: Session, sequence: Long, payload: JSONObject): JSONObject {
        val nonce = randomBytes(12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(session.key, "AES"), GCMParameterSpec(128, nonce))
        cipher.updateAAD(associatedData(session, sequence))
        val sealed = cipher.doFinal(payload.toString().toByteArray(Charsets.UTF_8))
        val ciphertext = sealed.copyOfRange(0, sealed.size - 16)
        val tag = sealed.copyOfRange(sealed.size - 16, sealed.size)
        return JSONObject().put("version", ProtocolVersion).put("sequence", sequence).put("nonce", nonce.base64Url()).put("ciphertext", ciphertext.base64Url()).put("tag", tag.base64Url())
    }

    private fun openEnvelope(session: Session, envelope: JSONObject): JSONObject {
        if (envelope.optString("version") != ProtocolVersion) error("invalid direct envelope")
        val sequence = envelope.optLong("sequence", -1)
        if (sequence < 0) error("invalid direct sequence")
        val nonce = envelope.getString("nonce").base64UrlDecode()
        val ciphertext = envelope.getString("ciphertext").base64UrlDecode()
        val tag = envelope.getString("tag").base64UrlDecode()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(session.key, "AES"), GCMParameterSpec(128, nonce))
        cipher.updateAAD(associatedData(session, sequence))
        val plaintext = cipher.doFinal(ciphertext + tag)
        val payload = JSONObject(plaintext.toString(Charsets.UTF_8))
        if (payload.optString("protocolVersion") != RpcProtocolVersion || payload.optString("sessionId") != session.sessionId || payload.optString("fromDeviceId") != session.peer.deviceId || payload.optString("toDeviceId") != deviceId) error("direct RPC binding mismatch")
        synchronized(session) {
            if (sequence <= session.highestReceived - ReplayWindow || !session.received.add(sequence)) error("direct RPC replay")
            if (sequence > session.highestReceived) session.highestReceived = sequence
            val floor = session.highestReceived - ReplayWindow
            session.received.removeAll { it <= floor }
        }
        return payload
    }

    private fun associatedData(session: Session, sequence: Long): ByteArray {
        val context = JSONObject()
            .put("directProtocolVersion", ProtocolVersion)
            .put("rpcProtocolVersion", RpcProtocolVersion)
            .put("accountId", accountBinding)
            .put("sessionId", session.sessionId)
            .put("peers", session.peersJson)
        return canonicalJson(JSONObject().put("protocolVersion", ProtocolVersion).put("context", context).put("sequence", sequence)).toByteArray(Charsets.UTF_8)
    }

    private fun rpcPeers(peer: Peer): JSONArray {
        val values = listOf(deviceId to generation, peer.deviceId to peer.generation).sortedBy { "${it.first}\u0000${it.second}" }
        return JSONArray().also { array -> values.forEach { array.put(JSONObject().put("deviceId", it.first).put("generation", it.second)) } }
    }

    private fun hkdf(input: ByteArray, salt: ByteArray, info: ByteArray, length: Int): ByteArray {
        val extract = Mac.getInstance("HmacSHA256")
        extract.init(SecretKeySpec(salt, "HmacSHA256"))
        val prk = extract.doFinal(input)
        val output = ArrayList<Byte>(length)
        var previous = ByteArray(0)
        var counter = 1
        while (output.size < length) {
            val expand = Mac.getInstance("HmacSHA256")
            expand.init(SecretKeySpec(prk, "HmacSHA256"))
            expand.update(previous)
            expand.update(info)
            expand.update(counter.toByte())
            previous = expand.doFinal()
            previous.forEach { if (output.size < length) output.add(it) }
            counter += 1
        }
        return output.toByteArray()
    }

    private fun signedPacket(type: String, toDeviceId: String, nonce: String): JSONObject {
        val packet = JSONObject().put("protocolVersion", ProtocolVersion).put("type", type).put("fromDeviceId", deviceId).put("fromGeneration", generation).put("toDeviceId", toDeviceId).put("nonce", nonce).put("sentAt", System.currentTimeMillis()).put("nodePublicKey", publicJwk)
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(keyPair.private)
        signer.update(payload(packet).toByteArray(Charsets.UTF_8))
        packet.put("signature", signer.sign().base64Url())
        return packet
    }

    private fun verifyPacket(packet: JSONObject, peer: Peer): Boolean {
        if (packet.optString("protocolVersion") != ProtocolVersion || packet.optString("type") !in setOf("probe", "probe-ack")) return false
        if (packet.optString("fromDeviceId") != peer.deviceId || packet.optString("fromGeneration") != peer.generation || packet.optString("toDeviceId") != deviceId) return false
        if (kotlin.math.abs(System.currentTimeMillis() - packet.optLong("sentAt")) > 60_000) return false
        val jwk = packet.optJSONObject("nodePublicKey") ?: return false
        if (fingerprint(jwk) != peer.fingerprint) return false
        return runCatching {
            val verifier = Signature.getInstance("SHA256withECDSA")
            verifier.initVerify(ecPublicKey(jwk))
            verifier.update(payload(packet).toByteArray(Charsets.UTF_8))
            verifier.verify(packet.optString("signature").base64UrlDecode())
        }.getOrDefault(false)
    }

    private fun ecPublicKey(jwk: JSONObject): ECPublicKey {
        val x = BigInteger(1, jwk.getString("x").base64UrlDecode())
        val y = BigInteger(1, jwk.getString("y").base64UrlDecode())
        val params = (keyPair.public as ECPublicKey).params
        return KeyFactory.getInstance("EC").generatePublic(ECPublicKeySpec(ECPoint(x, y), params)) as ECPublicKey
    }

    private fun payload(packet: JSONObject): String = canonicalJson(JSONObject().put("protocolVersion", packet.optString("protocolVersion")).put("type", packet.optString("type")).put("fromDeviceId", packet.optString("fromDeviceId")).put("fromGeneration", packet.optString("fromGeneration")).put("toDeviceId", packet.optString("toDeviceId")).put("nonce", packet.optString("nonce")).put("sentAt", packet.optLong("sentAt")).put("nodePublicKey", packet.optJSONObject("nodePublicKey")))

    private fun candidatesJson(): JSONArray = JSONArray().also { output ->
        candidates().forEach { candidate -> output.put(JSONObject().put("id", candidate.id).put("transport", "udp").put("scope", candidate.scope).put("host", candidate.host).put("port", candidate.port).put("priority", candidate.priority).put("observedAt", System.currentTimeMillis()).put("expiresAt", System.currentTimeMillis() + 120_000)) }
    }

    private fun sendJson(value: JSONObject, address: InetAddress, port: Int) {
        val encoded = value.toString().toByteArray(Charsets.UTF_8)
        require(encoded.size <= MaximumPacketBytes) { "direct packet too large" }
        socket.send(DatagramPacket(encoded, encoded.size, address, port))
    }

    override fun close() {
        if (!running.compareAndSet(true, false)) return
        pendingProbes.values.forEach { it.deferred.cancel() }
        pendingRpc.values.forEach { it.deferred.cancel() }
        pendingProbes.clear()
        pendingRpc.clear()
        sessions.clear()
        receiveJob?.cancel()
        socket.close()
    }

    private fun publicJwk(publicKey: ECPublicKey): JSONObject = JSONObject().put("kty", "EC").put("crv", "P-256").put("x", coordinate(publicKey.w.affineX).base64Url()).put("y", coordinate(publicKey.w.affineY).base64Url())
    private fun fingerprint(jwk: JSONObject): String = MessageDigest.getInstance("SHA-256").digest("${jwk.optString("kty")}:${jwk.optString("crv")}:${jwk.optString("x")}:${jwk.optString("y")}".toByteArray(Charsets.UTF_8)).base64Url().take(32)
    private fun coordinate(value: BigInteger): ByteArray {
        val bytes = value.toByteArray()
        return when { bytes.size == 32 -> bytes; bytes.size == 33 && bytes[0] == 0.toByte() -> bytes.copyOfRange(1, 33); bytes.size < 32 -> ByteArray(32 - bytes.size) + bytes; else -> bytes.copyOfRange(bytes.size - 32, bytes.size) }
    }
    private fun canonicalJson(value: Any?): String = when (value) {
        null, JSONObject.NULL -> "null"
        is String -> JSONObject.quote(value)
        is Boolean -> if (value) "true" else "false"
        is Number -> value.toString()
        is JSONArray -> (0 until value.length()).joinToString(prefix = "[", postfix = "]", separator = ",") { canonicalJson(value.opt(it)) }
        is JSONObject -> value.keys().asSequence().toList().sorted().joinToString(prefix = "{", postfix = "}", separator = ",") { key -> "${JSONObject.quote(key)}:${canonicalJson(value.opt(key))}" }
        else -> error("unsupported direct path canonical JSON")
    }
    private fun randomBytes(count: Int) = ByteArray(count).also(random::nextBytes)
    private fun ByteArray.base64Url(): String = Base64.encodeToString(this, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    private fun String.base64UrlDecode(): ByteArray = Base64.decode(this, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
}
