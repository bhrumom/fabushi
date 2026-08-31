package com.ombhrum.fabushi

import android.util.Base64
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
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
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec
import java.security.SecureRandom
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/** Authenticated UDP path discovery for the Fabushi account device mesh.
 *
 * This is not a VPN tunnel. It establishes and continuously verifies direct
 * reachability between same-account Fabushi nodes. Calls continue to have the
 * official WSS relay available whenever direct reachability is absent.
 */
class FabushiDeviceDirectPath(
    private val deviceId: String,
    private val generation: String,
    private val keyPair: KeyPair,
    private val scope: CoroutineScope,
) : Closeable {
    companion object {
        const val ProtocolVersion = "fabushi.direct-path.v1"
        private const val MaximumPacketBytes = 60 * 1024
        private const val ProbeTimeoutMilliseconds = 1_500L
    }

    data class Candidate(val id: String, val host: String, val port: Int, val priority: Int, val scope: String)
    data class Peer(val deviceId: String, val generation: String, val fingerprint: String, val candidates: List<Candidate>)
    data class Health(val targetDeviceId: String, val candidateId: String, val reachable: Boolean, val latencyMs: Long, val loss: Double)

    private data class Pending(val sentAt: Long, val deferred: CompletableDeferred<Long>)

    private val random = SecureRandom()
    private val running = AtomicBoolean(false)
    private val socket = DatagramSocket(0)
    private val peers = ConcurrentHashMap<String, Peer>()
    private val pending = ConcurrentHashMap<String, Pending>()
    private var receiveJob: Job? = null
    private val publicJwk = publicJwk(keyPair.public as ECPublicKey)
    private val fingerprint = fingerprint(publicJwk)

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
                val id = "udp:host:$host:${socket.localPort}"
                results += Candidate(id, host, socket.localPort, if (address is Inet4Address) 200 else 180, "host")
            }
        }
        return results.distinctBy(Candidate::id).take(24)
    }

    fun registrationJson(): JSONObject = JSONObject()
        .put("version", ProtocolVersion)
        .put("candidates", candidatesJson())

    fun heartbeatJson(): JSONObject = registrationJson()

    fun updatePeers(array: JSONArray?) {
        peers.clear()
        if (array == null) return
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
                val scope = candidate.optString("scope", "host")
                if (id.isEmpty() || host.isEmpty() || port !in 1..65535 || scope !in setOf("host", "srflx")) continue
                peerCandidates += Candidate(id, host, port, candidate.optInt("priority", 100), scope)
            }
            peers[peerId] = Peer(peerId, peerGeneration, peerFingerprint, peerCandidates)
        }
    }

    fun probeAll(report: (Health) -> Unit) {
        for (peer in peers.values) {
            for (candidate in peer.candidates.take(8)) {
                scope.launch(Dispatchers.IO) {
                    val startedAt = System.currentTimeMillis()
                    val latency = runCatching { probe(peer, candidate) }.getOrNull()
                    report(Health(
                        targetDeviceId = peer.deviceId,
                        candidateId = candidate.id,
                        reachable = latency != null,
                        latencyMs = latency ?: (System.currentTimeMillis() - startedAt),
                        loss = if (latency == null) 1.0 else 0.0,
                    ))
                }
            }
        }
    }

    private suspend fun probe(peer: Peer, candidate: Candidate): Long = withContext(Dispatchers.IO) {
        val nonce = randomBytes(18).base64Url()
        val packet = signedPacket("probe", peer.deviceId, nonce)
        val deferred = CompletableDeferred<Long>()
        pending[nonce] = Pending(System.currentTimeMillis(), deferred)
        try {
            val encoded = packet.toString().toByteArray(Charsets.UTF_8)
            require(encoded.size <= MaximumPacketBytes) { "direct probe too large" }
            socket.send(DatagramPacket(encoded, encoded.size, InetAddress.getByName(candidate.host), candidate.port))
            withTimeout(ProbeTimeoutMilliseconds) { deferred.await() }
        } finally {
            pending.remove(nonce)
        }
    }

    private fun handlePacket(bytes: ByteArray, address: InetAddress, port: Int) {
        if (bytes.size > MaximumPacketBytes) return
        val packet = runCatching { JSONObject(bytes.toString(Charsets.UTF_8)) }.getOrNull() ?: return
        val fromDeviceId = packet.optString("fromDeviceId")
        val peer = peers[fromDeviceId] ?: return
        if (!verifyPacket(packet, peer)) return
        when (packet.optString("type")) {
            "probe" -> {
                val response = signedPacket("probe-ack", peer.deviceId, packet.optString("nonce"))
                val encoded = response.toString().toByteArray(Charsets.UTF_8)
                runCatching { socket.send(DatagramPacket(encoded, encoded.size, address, port)) }
            }
            "probe-ack" -> {
                val nonce = packet.optString("nonce")
                val request = pending.remove(nonce) ?: return
                request.deferred.complete((System.currentTimeMillis() - request.sentAt).coerceAtLeast(0))
            }
        }
    }

    private fun signedPacket(type: String, toDeviceId: String, nonce: String): JSONObject {
        val packet = JSONObject()
            .put("protocolVersion", ProtocolVersion)
            .put("type", type)
            .put("fromDeviceId", deviceId)
            .put("fromGeneration", generation)
            .put("toDeviceId", toDeviceId)
            .put("nonce", nonce)
            .put("sentAt", System.currentTimeMillis())
            .put("nodePublicKey", publicJwk)
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(keyPair.private)
        signer.update(payload(packet).toByteArray(Charsets.UTF_8))
        packet.put("signature", signer.sign().base64Url())
        return packet
    }

    private fun verifyPacket(packet: JSONObject, peer: Peer): Boolean {
        if (packet.optString("protocolVersion") != ProtocolVersion) return false
        if (packet.optString("type") !in setOf("probe", "probe-ack")) return false
        if (packet.optString("fromDeviceId") != peer.deviceId || packet.optString("fromGeneration") != peer.generation) return false
        if (packet.optString("toDeviceId") != deviceId) return false
        if (kotlin.math.abs(System.currentTimeMillis() - packet.optLong("sentAt")) > 60_000) return false
        val jwk = packet.optJSONObject("nodePublicKey") ?: return false
        if (fingerprint(jwk) != peer.fingerprint) return false
        return runCatching {
            val x = BigInteger(1, jwk.getString("x").base64UrlDecode())
            val y = BigInteger(1, jwk.getString("y").base64UrlDecode())
            val params = (keyPair.public as ECPublicKey).params
            val publicKey = KeyFactory.getInstance("EC").generatePublic(ECPublicKeySpec(ECPoint(x, y), params))
            val verifier = Signature.getInstance("SHA256withECDSA")
            verifier.initVerify(publicKey)
            verifier.update(payload(packet).toByteArray(Charsets.UTF_8))
            verifier.verify(packet.optString("signature").base64UrlDecode())
        }.getOrDefault(false)
    }

    private fun payload(packet: JSONObject): String = canonicalJson(JSONObject()
        .put("protocolVersion", packet.optString("protocolVersion"))
        .put("type", packet.optString("type"))
        .put("fromDeviceId", packet.optString("fromDeviceId"))
        .put("fromGeneration", packet.optString("fromGeneration"))
        .put("toDeviceId", packet.optString("toDeviceId"))
        .put("nonce", packet.optString("nonce"))
        .put("sentAt", packet.optLong("sentAt"))
        .put("nodePublicKey", packet.optJSONObject("nodePublicKey")))

    private fun candidatesJson(): JSONArray = JSONArray().also { output ->
        candidates().forEach { candidate ->
            output.put(JSONObject()
                .put("id", candidate.id)
                .put("transport", "udp")
                .put("scope", candidate.scope)
                .put("host", candidate.host)
                .put("port", candidate.port)
                .put("priority", candidate.priority)
                .put("observedAt", System.currentTimeMillis())
                .put("expiresAt", System.currentTimeMillis() + 120_000))
        }
    }

    override fun close() {
        if (!running.compareAndSet(true, false)) return
        pending.values.forEach { it.deferred.cancel() }
        pending.clear()
        receiveJob?.cancel()
        socket.close()
    }

    private fun publicJwk(publicKey: ECPublicKey): JSONObject = JSONObject()
        .put("kty", "EC")
        .put("crv", "P-256")
        .put("x", coordinate(publicKey.w.affineX).base64Url())
        .put("y", coordinate(publicKey.w.affineY).base64Url())

    private fun fingerprint(jwk: JSONObject): String {
        val canonicalKey = "${jwk.optString("kty")}:${jwk.optString("crv")}:${jwk.optString("x")}:${jwk.optString("y")}"
        return MessageDigest.getInstance("SHA-256").digest(canonicalKey.toByteArray(Charsets.UTF_8)).base64Url().take(32)
    }

    private fun coordinate(value: BigInteger): ByteArray {
        val bytes = value.toByteArray()
        return when {
            bytes.size == 32 -> bytes
            bytes.size == 33 && bytes[0] == 0.toByte() -> bytes.copyOfRange(1, 33)
            bytes.size < 32 -> ByteArray(32 - bytes.size) + bytes
            else -> bytes.copyOfRange(bytes.size - 32, bytes.size)
        }
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
