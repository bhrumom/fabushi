import Foundation
import Network
import Security
import Darwin

/// Native authenticated UDP reachability for same-account Fabushi nodes.
/// Relay remains available whenever no healthy direct path is proven.
@MainActor
final class FabushiDeviceDirectPath {
    static let protocolVersion = "fabushi.direct-path.v1"

    struct Candidate: Hashable {
        let id: String
        let host: String
        let port: UInt16
        let priority: Int
        let scope: String

        var json: [String: Any] {
            [
                "id": id,
                "transport": "udp",
                "scope": scope,
                "host": host,
                "port": Int(port),
                "priority": priority,
                "observedAt": Int(Date().timeIntervalSince1970 * 1000),
                "expiresAt": Int(Date().addingTimeInterval(120).timeIntervalSince1970 * 1000),
            ]
        }
    }

    struct Peer {
        let deviceId: String
        let generation: String
        let fingerprint: String
        let candidates: [Candidate]
    }

    struct Health {
        let targetDeviceId: String
        let candidateId: String
        let reachable: Bool
        let latencyMs: Int
        let loss: Double
    }

    private let deviceId: String
    private let generation: String
    private let identity: FabushiMeshNodeIdentity
    private let queue = DispatchQueue(label: "com.ombhrum.fabushi.direct-path", qos: .userInitiated)
    private var listener: NWListener?
    private var boundPort: UInt16?
    private var peers: [String: Peer] = [:]
    private var incoming: [NWConnection] = []

    init(deviceId: String, generation: String, identity: FabushiMeshNodeIdentity) {
        self.deviceId = deviceId
        self.generation = generation
        self.identity = identity
    }

    func start() async throws {
        guard listener == nil else { return }
        let listener = try NWListener(using: .udp, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in self?.accept(connection) }
        }
        let ready = CheckedContinuationBox<Void>()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.resume(returning: ())
            case .failed(let error):
                ready.resume(throwing: error)
            default:
                break
            }
        }
        listener.start(queue: queue)
        try await ready.value()
        guard let port = listener.port?.rawValue else { throw DirectPathError.listenerPortUnavailable }
        boundPort = port
    }

    func stop() {
        listener?.cancel()
        listener = nil
        boundPort = nil
        for connection in incoming { connection.cancel() }
        incoming.removeAll()
        peers.removeAll()
    }

    func registrationJSON() -> [String: Any] {
        ["version": Self.protocolVersion, "candidates": candidates().map(\.json)]
    }

    func candidates() -> [Candidate] {
        guard let port = boundPort else { return [] }
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }
        var current: UnsafeMutablePointer<ifaddrs>? = first
        var result: [Candidate] = []
        while let interface = current?.pointee {
            defer { current = interface.ifa_next }
            guard let address = interface.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length: socklen_t = family == AF_INET ? socklen_t(MemoryLayout<sockaddr_in>.size) : socklen_t(MemoryLayout<sockaddr_in6>.size)
            guard getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            var addressText = String(cString: host)
            if let percent = addressText.firstIndex(of: "%") { addressText = String(addressText[..<percent]) }
            if addressText.isEmpty || addressText == "0.0.0.0" || addressText == "::" { continue }
            let priority = family == AF_INET ? 200 : 180
            result.append(Candidate(id: "udp:host:\(addressText):\(port)", host: addressText, port: port, priority: priority, scope: "host"))
        }
        return Array(Set(result)).sorted { $0.priority > $1.priority }.prefix(24).map { $0 }
    }

    func updatePeers(_ rawPeers: [[String: Any]]) {
        var updated: [String: Peer] = [:]
        for raw in rawPeers.prefix(50) {
            guard let peerId = raw["deviceId"] as? String,
                  let peerGeneration = raw["generation"] as? String,
                  let fingerprint = raw["nodeKeyFingerprint"] as? String,
                  !peerId.isEmpty, !peerGeneration.isEmpty, !fingerprint.isEmpty
            else { continue }
            let candidateValues = raw["candidates"] as? [[String: Any]] ?? []
            let candidates = candidateValues.prefix(24).compactMap(Self.parseCandidate)
            updated[peerId] = Peer(deviceId: peerId, generation: peerGeneration, fingerprint: fingerprint, candidates: candidates)
        }
        peers = updated
    }

    func probeAll(report: @escaping @MainActor (Health) -> Void) {
        let snapshot = peers
        for peer in snapshot.values {
            for candidate in peer.candidates.prefix(8) {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let started = Date()
                    do {
                        let latency = try await self.probe(peer: peer, candidate: candidate)
                        report(Health(targetDeviceId: peer.deviceId, candidateId: candidate.id, reachable: true, latencyMs: latency, loss: 0))
                    } catch {
                        report(Health(targetDeviceId: peer.deviceId, candidateId: candidate.id, reachable: false, latencyMs: max(0, Int(Date().timeIntervalSince(started) * 1000)), loss: 1))
                    }
                }
            }
        }
    }

    private func probe(peer: Peer, candidate: Candidate) async throws -> Int {
        let nonce = randomData(count: 18).base64URLString
        let packet = try signedPacket(type: "probe", toDeviceId: peer.deviceId, nonce: nonce)
        let connection = NWConnection(host: NWEndpoint.Host(candidate.host), port: NWEndpoint.Port(rawValue: candidate.port)!, using: .udp)
        defer { connection.cancel() }
        let started = Date()
        try await startConnection(connection)
        try await send(packet, over: connection)
        let response = try await receiveDatagram(connection, timeoutNanoseconds: 1_500_000_000)
        guard try verifyPacket(response, peer: peer, expectedType: "probe-ack"), response["nonce"] as? String == nonce else {
            throw DirectPathError.invalidPacket
        }
        return max(0, Int(Date().timeIntervalSince(started) * 1000))
    }

    private func accept(_ connection: NWConnection) {
        incoming.append(connection)
        connection.stateUpdateHandler = { [weak connection] state in
            if case .failed = state { connection?.cancel() }
        }
        connection.start(queue: queue)
        receiveIncoming(connection)
    }

    private func receiveIncoming(_ connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let connection else { return }
            Task { @MainActor [weak self] in
                guard let self else { connection.cancel(); return }
                defer {
                    connection.cancel()
                    self.incoming.removeAll { $0 === connection }
                }
                guard error == nil, let data, data.count <= 60 * 1024,
                      let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let fromDeviceId = packet["fromDeviceId"] as? String,
                      let peer = self.peers[fromDeviceId],
                      (try? self.verifyPacket(packet, peer: peer, expectedType: "probe")) == true,
                      let nonce = packet["nonce"] as? String
                else { return }
                guard let response = try? self.signedPacket(type: "probe-ack", toDeviceId: peer.deviceId, nonce: nonce),
                      let encoded = try? JSONSerialization.data(withJSONObject: response)
                else { return }
                connection.send(content: encoded, completion: .contentProcessed { _ in })
            }
        }
    }

    private func signedPacket(type: String, toDeviceId: String, nonce: String) throws -> [String: Any] {
        var packet: [String: Any] = [
            "protocolVersion": Self.protocolVersion,
            "type": type,
            "fromDeviceId": deviceId,
            "fromGeneration": generation,
            "toDeviceId": toDeviceId,
            "nonce": nonce,
            "sentAt": Int(Date().timeIntervalSince1970 * 1000),
            "nodePublicKey": identity.publicJWK,
        ]
        let payload = try Self.canonicalData(Self.probePayload(packet))
        packet["signature"] = try identity.sign(payload).base64URLString
        return packet
    }

    private func verifyPacket(_ packet: [String: Any], peer: Peer, expectedType: String) throws -> Bool {
        guard packet["protocolVersion"] as? String == Self.protocolVersion,
              packet["type"] as? String == expectedType,
              packet["fromDeviceId"] as? String == peer.deviceId,
              packet["fromGeneration"] as? String == peer.generation,
              packet["toDeviceId"] as? String == deviceId,
              let sentAt = packet["sentAt"] as? NSNumber,
              abs(Int(Date().timeIntervalSince1970 * 1000) - sentAt.intValue) <= 60_000,
              let jwk = packet["nodePublicKey"] as? [String: Any],
              Self.fingerprint(jwk) == peer.fingerprint,
              let signatureText = packet["signature"] as? String,
              let signature = Data(base64URL: signatureText)
        else { return false }
        let key = try Self.publicKey(from: jwk)
        let payload = try Self.canonicalData(Self.probePayload(packet))
        return SecKeyVerifySignature(key, .ecdsaSignatureMessageX962SHA256, payload as CFData, signature as CFData, nil)
    }

    private static func probePayload(_ packet: [String: Any]) -> [String: Any] {
        [
            "protocolVersion": packet["protocolVersion"] ?? "",
            "type": packet["type"] ?? "",
            "fromDeviceId": packet["fromDeviceId"] ?? "",
            "fromGeneration": packet["fromGeneration"] ?? "",
            "toDeviceId": packet["toDeviceId"] ?? "",
            "nonce": packet["nonce"] ?? "",
            "sentAt": packet["sentAt"] ?? 0,
            "nodePublicKey": packet["nodePublicKey"] ?? [:],
        ]
    }

    private static func parseCandidate(_ raw: [String: Any]) -> Candidate? {
        guard let id = raw["id"] as? String,
              let host = raw["host"] as? String,
              let portNumber = raw["port"] as? NSNumber,
              (1...65535).contains(portNumber.intValue)
        else { return nil }
        let scope = raw["scope"] as? String ?? "host"
        guard scope == "host" || scope == "srflx" else { return nil }
        return Candidate(id: id, host: host, port: UInt16(portNumber.intValue), priority: (raw["priority"] as? NSNumber)?.intValue ?? 100, scope: scope)
    }

    private static func publicKey(from jwk: [String: Any]) throws -> SecKey {
        guard jwk["kty"] as? String == "EC", jwk["crv"] as? String == "P-256",
              let xText = jwk["x"] as? String, let yText = jwk["y"] as? String,
              let x = Data(base64URL: xText), let y = Data(base64URL: yText), x.count == 32, y.count == 32
        else { throw DirectPathError.invalidPublicKey }
        var representation = Data([0x04])
        representation.append(x)
        representation.append(y)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: 256,
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(representation as CFData, attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? DirectPathError.invalidPublicKey as CFError
        }
        return key
    }

    private static func fingerprint(_ jwk: [String: Any]) -> String {
        guard let kty = jwk["kty"] as? String, let crv = jwk["crv"] as? String,
              let x = jwk["x"] as? String, let y = jwk["y"] as? String
        else { return "" }
        let digest = SHA256Digest.hash(Data("\(kty):\(crv):\(x):\(y)".utf8))
        return digest.base64URLString.prefix(32).description
    }

    private static func canonicalData(_ value: Any) throws -> Data {
        Data(try canonicalJSON(value).utf8)
    }

    private static func canonicalJSON(_ value: Any) throws -> String {
        if value is NSNull { return "null" }
        if let string = value as? String {
            let data = try JSONSerialization.data(withJSONObject: [string])
            let encoded = String(decoding: data, as: UTF8.self)
            return String(encoded.dropFirst().dropLast())
        }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let number = value as? NSNumber { return number.stringValue }
        if let array = value as? [Any] { return "[\(try array.map(canonicalJSON).joined(separator: ","))]" }
        if let object = value as? [String: Any] {
            let fields = try object.keys.sorted().map { key in
                "\(try canonicalJSON(key)):\(try canonicalJSON(object[key] as Any))"
            }
            return "{\(fields.joined(separator: ","))}"
        }
        throw DirectPathError.invalidPacket
    }

    private func startConnection(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let box = CheckedContinuationBox<Void>(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: box.resume(returning: ())
                case .failed(let error): box.resume(throwing: error)
                default: break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send(_ object: [String: Any], over connection: NWConnection) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            })
        }
    }

    private func receiveDatagram(_ connection: NWConnection, timeoutNanoseconds: UInt64) async throws -> [String: Any] {
        try await withThrowingTaskGroup(of: [String: Any].self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    connection.receiveMessage { data, _, _, error in
                        if let error { continuation.resume(throwing: error); return }
                        guard let data, data.count <= 60 * 1024,
                              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continuation.resume(throwing: DirectPathError.invalidPacket); return }
                        continuation.resume(returning: object)
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw DirectPathError.timeout
            }
            guard let result = try await group.next() else { throw DirectPathError.timeout }
            group.cancelAll()
            return result
        }
    }

    private func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}

private enum DirectPathError: Error {
    case listenerPortUnavailable
    case invalidPacket
    case invalidPublicKey
    case timeout
}

private final class CheckedContinuationBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    init(_ continuation: CheckedContinuation<Value, Error>? = nil) { self.continuation = continuation }
    func set(_ continuation: CheckedContinuation<Value, Error>) { lock.lock(); defer { lock.unlock() }; self.continuation = continuation }
    func value() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in set(continuation) }
    }
    func resume(returning value: Value) { lock.lock(); let continuation = self.continuation; self.continuation = nil; lock.unlock(); continuation?.resume(returning: value) }
    func resume(throwing error: Error) { lock.lock(); let continuation = self.continuation; self.continuation = nil; lock.unlock(); continuation?.resume(throwing: error) }
}

private enum SHA256Digest {
    static func hash(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
}

private extension Data {
    var base64URLString: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    init?(base64URL value: String) {
        var text = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 { text.append("=") }
        self.init(base64Encoded: text)
    }
}
