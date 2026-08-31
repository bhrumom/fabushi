import CryptoKit
import Foundation
import Network
import Security
import Darwin

/// Native authenticated UDP reachability and encrypted peer RPC for same-account Fabushi nodes.
/// Relay remains available whenever direct connectivity or key agreement is unavailable.
@MainActor
final class FabushiDeviceDirectPath {
    static let protocolVersion = "fabushi.direct-path.v1"
    static let rpcProtocolVersion = "fabushi.direct-rpc.v1"
    private static let rpcPacketType = "fabushi-direct-rpc"
    private static let replayWindow: UInt64 = 128

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

    private final class RPCSession {
        let peer: Peer
        let key: SymmetricKey
        let sessionId: String
        let peerBinding: [[String: String]]
        var sendSequence: UInt64 = 0
        var highestReceived: UInt64?
        var received = Set<UInt64>()

        init(peer: Peer, key: SymmetricKey, sessionId: String, peerBinding: [[String: String]]) {
            self.peer = peer
            self.key = key
            self.sessionId = sessionId
            self.peerBinding = peerBinding
        }
    }

    typealias RPCExecutor = @MainActor (_ invocationId: String, _ toolName: String, _ arguments: [String: Any]) async throws -> [String: Any]

    private let deviceId: String
    private let generation: String
    private let identity: FabushiMeshNodeIdentity
    private let queue = DispatchQueue(label: "com.ombhrum.fabushi.direct-path", qos: .userInitiated)
    private var listener: NWListener?
    private var boundPort: UInt16?
    private var peers: [String: Peer] = [:]
    private var incoming: [NWConnection] = []
    private var sessions: [String: RPCSession] = [:]
    private var accountBinding: String?
    private var rpcExecutor: RPCExecutor?

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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = VoidContinuationBox(continuation)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready: box.resume() // GBF-412 Swift 6 void continuation
                case .failed(let error): box.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: queue)
        } // GBF-412 await UDP listener readiness // GBF-412 Swift 6 start continuation
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
        sessions.removeAll()
        accountBinding = nil
        rpcExecutor = nil
    }

    func configureRPC(accountBinding: String?, executor: @escaping RPCExecutor) {
        let normalized = accountBinding?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalized.count < 16 {
            self.accountBinding = nil
            sessions.removeAll()
        } else if self.accountBinding != normalized {
            self.accountBinding = String(normalized.prefix(128))
            sessions.removeAll()
        }
        rpcExecutor = executor
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
            let nul = host.firstIndex(of: 0) ?? host.endIndex
            var addressText = String(decoding: host[..<nul].map { UInt8(bitPattern: $0) }, as: UTF8.self)
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
        sessions = sessions.filter { key, session in updated[key]?.generation == session.peer.generation }
    }

    func peer(deviceId: String) -> Peer? { peers[deviceId] }
    func preferredCandidate(for peer: Peer) -> Candidate? { peer.candidates.first }

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

    func call(
        peer: Peer,
        candidate: Candidate,
        toolName: String,
        arguments: [String: Any],
        invocationId: String,
        timeoutNanoseconds: UInt64 = 2_500_000_000
    ) async throws -> [String: Any] {
        guard invocationId.range(of: #"^[A-Za-z0-9._:-]{16,128}$"#, options: .regularExpression) != nil,
              toolName.range(of: #"^[A-Za-z0-9._-]{1,128}$"#, options: .regularExpression) != nil
        else { throw DirectPathError.invalidPacket }
        if sessions[peer.deviceId]?.peer.generation != peer.generation {
            _ = try await probe(peer: peer, candidate: candidate)
        }
        guard let session = sessions[peer.deviceId] else { throw DirectPathError.rpcUnavailable }
        let connection = NWConnection(host: NWEndpoint.Host(candidate.host), port: NWEndpoint.Port(rawValue: candidate.port)!, using: .udp)
        defer { connection.cancel() }
        try await startConnection(connection)
        let payload: [String: Any] = [
            "protocolVersion": Self.rpcProtocolVersion,
            "kind": "call",
            "invocationId": invocationId,
            "toolName": toolName,
            "arguments": arguments,
            "fromDeviceId": deviceId,
            "toDeviceId": peer.deviceId,
            "sessionId": session.sessionId,
        ]
        try await send(try rpcOuter(session: session, payload: payload), over: connection)
        let response = try await receiveDatagram(connection, timeoutNanoseconds: min(max(timeoutNanoseconds, 500_000_000), 5_000_000_000))
        guard response["type"] as? String == Self.rpcPacketType,
              response["fromDeviceId"] as? String == peer.deviceId,
              response["fromGeneration"] as? String == peer.generation,
              response["sessionId"] as? String == session.sessionId,
              let envelope = response["envelope"] as? [String: Any]
        else { throw DirectPathError.invalidPacket }
        let opened = try openEnvelope(session: session, envelope: envelope)
        if opened["kind"] as? String == "error" || (opened["ok"] as? Bool) == false {
            throw DirectPathError.rpcFailed(String(describing: opened["error"] ?? "direct RPC failed"))
        }
        return opened
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
        try establishSession(packet: response, peer: peer)
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
                      let peer = self.peers[fromDeviceId]
                else { return }
                if let type = packet["type"] as? String, type == "probe" {
                    guard (try? self.verifyPacket(packet, peer: peer, expectedType: "probe")) == true,
                          let nonce = packet["nonce"] as? String else { return }
                    try? self.establishSession(packet: packet, peer: peer)
                    guard let response = try? self.signedPacket(type: "probe-ack", toDeviceId: peer.deviceId, nonce: nonce) else { return }
                    try? await self.send(response, over: connection)
                    return
                }
                guard packet["type"] as? String == Self.rpcPacketType,
                      packet["fromGeneration"] as? String == peer.generation,
                      packet["toDeviceId"] as? String == self.deviceId,
                      let session = self.sessions[peer.deviceId],
                      packet["sessionId"] as? String == session.sessionId,
                      let envelope = packet["envelope"] as? [String: Any],
                      let opened = try? self.openEnvelope(session: session, envelope: envelope),
                      opened["kind"] as? String == "call",
                      let invocationId = opened["invocationId"] as? String,
                      let toolName = opened["toolName"] as? String,
                      let executor = self.rpcExecutor
                else { return }
                let arguments = opened["arguments"] as? [String: Any] ?? [:]
                var responsePayload: [String: Any]
                do {
                    let result = try await executor(invocationId, toolName, arguments)
                    responsePayload = [
                        "protocolVersion": Self.rpcProtocolVersion,
                        "kind": "result",
                        "invocationId": invocationId,
                        "ok": true,
                        "result": result,
                    ]
                } catch {
                    responsePayload = [
                        "protocolVersion": Self.rpcProtocolVersion,
                        "kind": "error",
                        "invocationId": invocationId,
                        "ok": false,
                        "error": String(self.safeRPCError(error).prefix(4_000)),
                    ]
                }
                responsePayload["fromDeviceId"] = self.deviceId
                responsePayload["toDeviceId"] = peer.deviceId
                responsePayload["sessionId"] = session.sessionId
                if let outer = try? self.rpcOuter(session: session, payload: responsePayload) {
                    try? await self.send(outer, over: connection)
                }
            }
        }
    }

    private func establishSession(packet: [String: Any], peer: Peer) throws {
        guard let binding = accountBinding, binding.count >= 16,
              let jwk = packet["nodePublicKey"] as? [String: Any]
        else { throw DirectPathError.rpcUnavailable }
        let peerKey = try Self.publicKey(from: jwk)
        guard SecKeyIsAlgorithmSupported(identity.privateKey, .keyExchange, .ecdhKeyExchangeStandard) else {
            throw DirectPathError.keyAgreementUnavailable
        }
        var error: Unmanaged<CFError>?
        guard let secret = SecKeyCopyKeyExchangeResult(
            identity.privateKey,
            .ecdhKeyExchangeStandard,
            peerKey,
            [:] as CFDictionary,
            &error
        ) as Data? else {
            if let error { throw error.takeRetainedValue() }
            throw DirectPathError.keyAgreementUnavailable
        }
        let peerBinding = [
            ["deviceId": deviceId, "generation": generation],
            ["deviceId": peer.deviceId, "generation": peer.generation],
        ].sorted { "\($0["deviceId"]!)\u{0000}\($0["generation"]!)" < "\($1["deviceId"]!)\u{0000}\($1["generation"]!)" }
        let sessionBinding: [String: Any] = [
            "protocolVersion": Self.rpcProtocolVersion,
            "accountId": binding,
            "peers": peerBinding,
        ]
        let canonical = try Self.canonicalData(sessionBinding)
        let sessionId = Data(SHA256.hash(data: canonical)).base64URLString.prefix(32).description
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: secret),
            salt: Data(Self.protocolVersion.utf8),
            info: canonical,
            outputByteCount: 32
        )
        sessions[peer.deviceId] = RPCSession(peer: peer, key: key, sessionId: sessionId, peerBinding: peerBinding)
    }

    private func rpcOuter(session: RPCSession, payload: [String: Any]) throws -> [String: Any] {
        let envelope = try sealEnvelope(session: session, payload: payload)
        return [
            "protocolVersion": Self.protocolVersion,
            "type": Self.rpcPacketType,
            "fromDeviceId": deviceId,
            "fromGeneration": generation,
            "toDeviceId": session.peer.deviceId,
            "sessionId": session.sessionId,
            "envelope": envelope,
        ]
    }

    private func sealEnvelope(session: RPCSession, payload: [String: Any]) throws -> [String: Any] {
        let sequence = session.sendSequence
        session.sendSequence += 1
        let aad = try associatedData(session: session, sequence: sequence)
        let plaintext = try JSONSerialization.data(withJSONObject: payload)
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(plaintext, using: session.key, nonce: nonce, authenticating: aad)
        return [
            "version": Self.protocolVersion,
            "sequence": NSNumber(value: sequence),
            "nonce": Data(nonce).base64URLString,
            "ciphertext": box.ciphertext.base64URLString,
            "tag": box.tag.base64URLString,
        ]
    }

    private func openEnvelope(session: RPCSession, envelope: [String: Any]) throws -> [String: Any] {
        guard envelope["version"] as? String == Self.protocolVersion,
              let sequenceNumber = envelope["sequence"] as? NSNumber,
              sequenceNumber.int64Value >= 0,
              let nonceText = envelope["nonce"] as? String, let nonceData = Data(base64URL: nonceText),
              let ciphertextText = envelope["ciphertext"] as? String, let ciphertext = Data(base64URL: ciphertextText),
              let tagText = envelope["tag"] as? String, let tag = Data(base64URL: tagText)
        else { throw DirectPathError.invalidPacket }
        let sequence = sequenceNumber.uint64Value
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plaintext = try AES.GCM.open(box, using: session.key, authenticating: associatedData(session: session, sequence: sequence))
        guard let payload = try JSONSerialization.jsonObject(with: plaintext) as? [String: Any],
              payload["protocolVersion"] as? String == Self.rpcProtocolVersion,
              payload["sessionId"] as? String == session.sessionId,
              payload["fromDeviceId"] as? String == session.peer.deviceId,
              payload["toDeviceId"] as? String == deviceId
        else { throw DirectPathError.invalidPacket }
        if let highest = session.highestReceived, sequence <= highest &- min(highest, Self.replayWindow) {
            throw DirectPathError.replay
        }
        guard !session.received.contains(sequence) else { throw DirectPathError.replay }
        session.received.insert(sequence)
        if session.highestReceived == nil || sequence > session.highestReceived! { session.highestReceived = sequence }
        if let highest = session.highestReceived {
            let floor = highest > Self.replayWindow ? highest - Self.replayWindow : 0
            session.received = session.received.filter { $0 > floor }
        }
        return payload
    }

    private func associatedData(session: RPCSession, sequence: UInt64) throws -> Data {
        let context: [String: Any] = [
            "directProtocolVersion": Self.protocolVersion,
            "rpcProtocolVersion": Self.rpcProtocolVersion,
            "accountId": accountBinding ?? "",
            "sessionId": session.sessionId,
            "peers": session.peerBinding,
        ]
        return try Self.canonicalData([
            "protocolVersion": Self.protocolVersion,
            "context": context,
            "sequence": NSNumber(value: sequence),
        ])
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
            if let error { throw error.takeRetainedValue() }
            throw DirectPathError.invalidPublicKey
        } // GBF-412 valid SecKey error propagation
        return key
    }

    private static func fingerprint(_ jwk: [String: Any]) -> String {
        guard let kty = jwk["kty"] as? String, let crv = jwk["crv"] as? String,
              let x = jwk["x"] as? String, let y = jwk["y"] as? String
        else { return "" }
        let digest = Data(SHA256.hash(data: Data("\(kty):\(crv):\(x):\(y)".utf8)))
        return digest.base64URLString.prefix(32).description // GBF-412 CryptoKit fingerprint
    }

    private static func canonicalData(_ value: Any) throws -> Data { Data(try canonicalJSON(value).utf8) }

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
            let fields = try object.keys.sorted().map { key in "\(try canonicalJSON(key)):\(try canonicalJSON(object[key] as Any))" }
            return "{\(fields.joined(separator: ","))}"
        }
        if let array = value as? [[String: String]] { return try canonicalJSON(array.map { $0 as [String: Any] }) }
        if let object = value as? [String: String] { return try canonicalJSON(object as [String: Any]) }
        throw DirectPathError.invalidPacket
    }

    private func startConnection(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = VoidContinuationBox(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: box.resume()
                case .failed(let error): box.resume(throwing: error)
                default: break
                }
            }
            connection.start(queue: queue)
        } // GBF-412 Swift 6 start continuation
    }

    private func send(_ object: [String: Any], over connection: NWConnection) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            })
        } // GBF-412 Swift 6 send continuation
    }

    private func receiveDatagram(_ connection: NWConnection, timeoutNanoseconds: UInt64) async throws -> [String: Any] {
        let data = try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    connection.receiveMessage { data, _, _, error in
                        if let error { continuation.resume(throwing: error); return }
                        guard let data, data.count <= 60 * 1024 else {
                            continuation.resume(throwing: DirectPathError.invalidPacket)
                            return
                        }
                        continuation.resume(returning: data)
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
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DirectPathError.invalidPacket }
        return object // GBF-412 Swift 6 Sendable datagram boundary
    }

    private func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private func safeRPCError(_ error: Error) -> String {
        (error as NSError).localizedDescription
            .replacingOccurrences(of: #"(?i)(bearer|token|password|secret)\s*[:=]?\s*[^\s,;]+"#, with: "$1=<redacted>", options: .regularExpression)
    }
}

private enum DirectPathError: Error {
    case listenerPortUnavailable
    case invalidPacket
    case invalidPublicKey
    case timeout
    case keyAgreementUnavailable
    case rpcUnavailable
    case rpcFailed(String)
    case replay
}

private final class VoidContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    init(_ continuation: CheckedContinuation<Void, Error>) { self.continuation = continuation }
    func resume() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: ())
    }
    func resume(throwing error: Error) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(throwing: error)
    }
} // GBF-412 Swift 6 void continuation holder

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
