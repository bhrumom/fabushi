import Foundation
import Security
import UIKit

/// Account-scoped iOS device agent for the shared `fabushi.app.*` contract.
///
/// iOS does not promise a permanently running application WebSocket. This
/// agent therefore registers only while the application is active and closes
/// the socket when the scene backgrounds. The gateway consequently reports
/// the device as offline instead of accepting calls against suspended UI.
@MainActor
final class FabushiDeviceMeshAgent {
    struct State: Equatable {
        var running = false
        var applicationActive = false
        var connected = false
        var registered = false
        var deviceId: String?
        var nodeFingerprint: String?
        var error: String?
    }

    private struct AccountSession {
        let accessToken: String
        let deviceId: String
    }

    private enum AgentError: LocalizedError {
        case invalidGateway
        case invalidAccountSession
        case invalidJSON
        case messageTooLarge
        case unsupportedTool
        case invalidArguments(String)

        var errorDescription: String? {
            switch self {
            case .invalidGateway: "device_mesh_gateway_url_invalid"
            case .invalidAccountSession: "fabushi_account_device_session_invalid"
            case .invalidJSON: "device_mesh_message_invalid_json"
            case .messageTooLarge: "device_mesh_message_too_large"
            case .unsupportedTool: "device_mesh_tool_unsupported"
            case .invalidArguments(let detail): "device_mesh_arguments_invalid: \(detail)"
            }
        }
    }

    static let officialGatewayURL = URL(string: "wss://fabushi-mcp.ombhrum.com/agent")!

    private static let heartbeatNanoseconds: UInt64 = 20_000_000_000
    private static let maximumReconnectNanoseconds: UInt64 = 30_000_000_000
    private static let maximumMessageBytes = 32 * 1024 * 1024

    private let host: MahayanaHost
    private let surface: FabushiAppAgentSurface
    private let gatewayURL: URL
    private let session: URLSession

    private(set) var state = State()
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var webSocket: URLSessionWebSocketTask?
    private var connectionGeneration: String?

    init(
        host: MahayanaHost,
        surface: FabushiAppAgentSurface,
        gatewayURL: URL = FabushiDeviceMeshAgent.officialGatewayURL
    ) {
        self.host = host
        self.surface = surface
        self.gatewayURL = gatewayURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    func start(applicationActive: Bool) {
        guard !state.running else {
            setApplicationActive(applicationActive)
            return
        }
        state.running = true
        state.applicationActive = applicationActive
        state.error = nil
        if applicationActive { scheduleConnect(after: 0) }
    }

    func setApplicationActive(_ active: Bool) {
        guard state.applicationActive != active else { return }
        state.applicationActive = active
        if active {
            state.error = nil
            scheduleConnect(after: 0)
        } else {
            surface.clear()
            disconnect(code: .goingAway, reason: "Fabushi entered background", reconnect: false)
        }
    }

    func stop() {
        guard state.running else { return }
        state.running = false
        disconnect(code: .normalClosure, reason: "Fabushi device agent stopping", reconnect: false)
        state = State(running: false, applicationActive: state.applicationActive)
        session.invalidateAndCancel()
    }

    private func scheduleConnect(after nanoseconds: UInt64) {
        guard state.running, state.applicationActive else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            if nanoseconds > 0 {
                do { try await Task.sleep(nanoseconds: nanoseconds) }
                catch { return }
            }
            guard let self, self.state.running, self.state.applicationActive else { return }
            await self.connect()
        }
    }

    private func connect() async {
        guard webSocket == nil, state.running, state.applicationActive else { return }
        do {
            let account = try await accountSession()
            let identity = try FabushiMeshNodeIdentity.loadOrCreate()
            let catalog = toolCatalog()
            let schemaVersion = try FabushiMeshNodeIdentity.schemaVersion(catalog)
            let generation = try randomData(count: 24).base64URLString
            let request = try gatewayRequest(accessToken: account.accessToken)
            let socket = session.webSocketTask(with: request)
            webSocket = socket
            connectionGeneration = generation
            state.deviceId = account.deviceId
            state.nodeFingerprint = identity.fingerprint
            state.connected = false
            state.registered = false
            state.error = nil
            socket.resume()

            let registration = try signedRegistration(
                identity: identity,
                account: account,
                generation: generation,
                toolSchemaVersion: schemaVersion,
                catalog: catalog
            )
            try await send(registration, over: socket)
            guard webSocket === socket else { return }
            reconnectAttempt = 0
            state.connected = true
            beginReceiveLoop(socket)
            beginHeartbeatLoop(socket)
        } catch {
            connectionFailed(webSocket, error: error)
        }
    }

    private func gatewayRequest(accessToken: String) throws -> URLRequest {
        guard gatewayURL.scheme == "wss", gatewayURL.host != nil else { throw AgentError.invalidGateway }
        var request = URLRequest(url: gatewayURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        return request
    }

    private func accountSession() async throws -> AccountSession {
        let result = try await host.request(method: "feature.auth.deviceAgentSession")
        guard let object = result.value as? [String: Any],
              let rawAccessToken = object["accessToken"] as? String,
              let rawDeviceId = object["deviceId"] as? String
        else { throw AgentError.invalidAccountSession }
        let accessToken = rawAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedDeviceId = rawDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (24...16_384).contains(accessToken.count),
              accessToken.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              requestedDeviceId.range(of: #"^[A-Za-z0-9._:-]{1,128}$"#, options: .regularExpression) != nil
        else { throw AgentError.invalidAccountSession }
        let suffix = "-ios"
        let deviceId: String
        if requestedDeviceId.hasSuffix(suffix) {
            deviceId = requestedDeviceId
        } else {
            deviceId = String(requestedDeviceId.prefix(128 - suffix.count)) + suffix
        }
        return AccountSession(accessToken: accessToken, deviceId: deviceId)
    }

    private func signedRegistration(
        identity: FabushiMeshNodeIdentity,
        account: AccountSession,
        generation: String,
        toolSchemaVersion: String,
        catalog: [[String: Any]]
    ) throws -> [String: Any] {
        let nonce = try randomData(count: 24).base64URLString
        let payload = identity.registrationPayload(
            deviceId: account.deviceId,
            generation: generation,
            toolSchemaVersion: toolSchemaVersion,
            nonce: nonce
        )
        let signature = try identity.sign(payload).base64URLString
        let device = UIDevice.current
        let name = "Fabushi on \(device.name)"
        let mesh: [String: Any] = [
            "protocolVersion": FabushiMeshNodeIdentity.protocolVersion,
            "nodePublicKey": identity.publicJWK,
            "nonce": nonce,
            "signature": signature,
            "features": [
                "account-scoped-discovery",
                "signed-node-identity",
                "lease-heartbeat",
                "relay-fallback",
                "path-observability",
                "capability-catalog",
            ],
            "supportedPaths": ["relay"],
            "preferredPath": "relay",
            "activePath": "relay",
            "tags": ["client:fabushi", "platform:ios", "role:mobile"],
            "posture": posture(appState: "foreground"),
        ]
        return [
            "type": "register",
            "deviceId": account.deviceId,
            "name": String(name.prefix(200)),
            "platform": "ios",
            "generation": generation,
            "leaseSeconds": 14_400,
            "capabilities": FabushiAppAgentSurface.toolNames,
            "tools": catalog,
            "metadata": [
                "kind": "fabushi-mobile",
                "runnerOs": "iOS \(device.systemVersion)",
                "runnerArch": architectureName(),
            ],
            "mesh": mesh,
        ]
    }

    private func beginReceiveLoop(_ socket: URLSessionWebSocketTask) {
        receiveTask?.cancel()
        receiveTask = Task { [weak self, weak socket] in
            guard let self, let socket else { return }
            while !Task.isCancelled, self.webSocket === socket {
                do {
                    let message = try await socket.receive()
                    try await self.handle(message, from: socket)
                } catch {
                    self.connectionFailed(socket, error: error)
                    return
                }
            }
        }
    }

    private func beginHeartbeatLoop(_ socket: URLSessionWebSocketTask) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, weak socket] in
            guard let self, let socket else { return }
            while !Task.isCancelled, self.webSocket === socket {
                do { try await Task.sleep(nanoseconds: Self.heartbeatNanoseconds) }
                catch { return }
                guard self.webSocket === socket, self.state.applicationActive else { return }
                do {
                    try await self.send([
                        "type": "heartbeat",
                        "at": Int64(Date().timeIntervalSince1970 * 1_000),
                        "mesh": [
                            "activePath": "relay",
                            "posture": self.posture(appState: self.surface.status().available ? "foreground" : "foreground-unavailable"),
                        ],
                    ], over: socket)
                } catch {
                    self.connectionFailed(socket, error: error)
                    return
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message, from socket: URLSessionWebSocketTask) async throws {
        let data: Data
        switch message {
        case .data(let payload): data = payload
        case .string(let text): data = Data(text.utf8)
        @unknown default: throw AgentError.invalidJSON
        }
        guard data.count <= Self.maximumMessageBytes else { throw AgentError.messageTooLarge }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { throw AgentError.invalidJSON }
        switch type {
        case "registered":
            guard webSocket === socket else { return }
            state.registered = true
            state.error = nil
        case "call":
            try await handleCall(object, from: socket)
        default:
            break
        }
    }

    private func handleCall(_ message: [String: Any], from socket: URLSessionWebSocketTask) async throws {
        guard let requestId = message["requestId"] as? String,
              requestId.range(of: #"^[A-Fa-f0-9]{16,64}$"#, options: .regularExpression) != nil,
              let toolName = message["toolName"] as? String,
              FabushiAppAgentSurface.toolNames.contains(toolName)
        else { return }
        let arguments = message["arguments"] as? [String: Any] ?? [:]
        let response: [String: Any]
        do {
            let structured = try await call(toolName: toolName, arguments: arguments)
            response = [
                "type": "result",
                "requestId": requestId,
                "ok": true,
                "result": [
                    "structuredContent": structured,
                    "content": [["type": "text", "text": summary(toolName: toolName, result: structured)]],
                ],
            ]
        } catch {
            response = [
                "type": "result",
                "requestId": requestId,
                "ok": false,
                "error": safeError(error),
            ]
        }
        guard webSocket === socket else { return }
        try await send(response, over: socket)
    }

    private func call(toolName: String, arguments: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "fabushi.app.status":
            return statusDictionary(surface.status())
        case "fabushi.app.snapshot":
            let maximum = max(1, min(500, integer(arguments["maxElements"]) ?? 500))
            return snapshotDictionary(surface.snapshot(), maximumElements: maximum)
        case "fabushi.app.find":
            let matches = surface.find(
                agentId: optionalString(arguments["agentId"]),
                role: optionalString(arguments["role"]),
                name: optionalString(arguments["name"]) ?? optionalString(arguments["text"]),
                limit: integer(arguments["limit"]) ?? 25
            )
            return ["count": matches.count, "matches": elementDictionaries(matches)]
        case "fabushi.app.action":
            guard let agentId = optionalString(arguments["agentId"]),
                  let action = optionalString(arguments["action"]),
                  let generation = unsignedInteger(arguments["generation"])
            else { throw AgentError.invalidArguments("generation, agentId and action are required") }
            return snapshotDictionary(try surface.perform(
                expectedGeneration: generation,
                agentId: agentId,
                action: action,
                value: optionalString(arguments["value"])
            ))
        case "fabushi.app.wait":
            return assertionDictionary(await surface.waitFor(
                screen: optionalString(arguments["screen"]),
                agentId: optionalString(arguments["agentId"]),
                role: optionalString(arguments["role"]),
                name: optionalString(arguments["name"]) ?? optionalString(arguments["text"]),
                state: optionalString(arguments["state"]) ?? "present",
                timeoutMilliseconds: UInt64(max(100, min(30_000, integer(arguments["timeoutMs"]) ?? 10_000)))
            ))
        case "fabushi.app.assert":
            return assertionDictionary(surface.assertState(
                screen: optionalString(arguments["screen"]),
                agentId: optionalString(arguments["agentId"]),
                role: optionalString(arguments["role"]),
                name: optionalString(arguments["name"]) ?? optionalString(arguments["text"]),
                state: optionalString(arguments["state"]) ?? "present"
            ))
        default:
            throw AgentError.unsupportedTool
        }
    }

    private func toolCatalog() -> [[String: Any]] {
        func descriptor(
            _ name: String,
            description: String,
            properties: [String: Any] = [:]
        ) -> [String: Any] {
            [
                "name": name,
                "title": name,
                "description": description,
                "inputSchema": [
                    "type": "object",
                    "properties": properties,
                    "additionalProperties": false,
                ],
                "annotations": [
                    "readOnlyHint": name != "fabushi.app.action",
                    "destructiveHint": name == "fabushi.app.action",
                    "idempotentHint": name != "fabushi.app.action",
                    "openWorldHint": false,
                ],
            ]
        }
        let query: [String: Any] = [
            "agentId": ["type": "string"],
            "role": ["type": "string"],
            "name": ["type": "string"],
            "text": ["type": "string"],
            "state": ["type": "string"],
            "screen": ["type": "string"],
        ]
        var find = query
        find["limit"] = ["type": "integer", "minimum": 1, "maximum": 100]
        var wait = query
        wait["timeoutMs"] = ["type": "integer", "minimum": 100, "maximum": 30_000]
        return [
            descriptor("fabushi.app.status", description: "Read iOS Fabushi App MCP availability."),
            descriptor("fabushi.app.snapshot", description: "Read the redacted iOS Fabushi semantic surface.", properties: [
                "maxElements": ["type": "integer", "minimum": 1, "maximum": 500],
            ]),
            descriptor("fabushi.app.find", description: "Find iOS Fabushi semantic elements.", properties: find),
            descriptor("fabushi.app.action", description: "Invoke a generation-bound iOS Fabushi semantic action.", properties: [
                "generation": ["type": "integer"],
                "agentId": ["type": "string"],
                "action": ["type": "string"],
                "value": ["type": "string"],
            ]),
            descriptor("fabushi.app.wait", description: "Wait for an iOS Fabushi semantic condition.", properties: wait),
            descriptor("fabushi.app.assert", description: "Assert an iOS Fabushi semantic condition.", properties: query),
        ]
    }

    private func posture(appState: String) -> [String: String] {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        let device = UIDevice.current
        return [
            "appVersion": String(version.prefix(240)),
            "buildNumber": String(build.prefix(240)),
            "deviceClass": device.userInterfaceIdiom == .pad ? "tablet" : "phone",
            "deviceModel": String(device.model.prefix(240)),
            "osVersion": String("iOS \(device.systemVersion)".prefix(240)),
            "appState": String(appState.prefix(240)),
        ].filter { !$0.value.isEmpty }
    }

    private func send(_ object: [String: Any], over socket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard data.count <= Self.maximumMessageBytes,
              let text = String(data: data, encoding: .utf8)
        else { throw AgentError.messageTooLarge }
        try await socket.send(.string(text))
    }

    private func connectionFailed(_ socket: URLSessionWebSocketTask?, error: Error) {
        guard socket == nil || webSocket === socket else { return }
        let deviceId = state.deviceId
        let fingerprint = state.nodeFingerprint
        disconnect(code: .goingAway, reason: "Fabushi mesh connection failed", reconnect: false)
        state.deviceId = deviceId
        state.nodeFingerprint = fingerprint
        state.error = safeError(error)
        guard state.running, state.applicationActive else { return }
        let exponent = min(reconnectAttempt, 6)
        reconnectAttempt += 1
        let delay = min(UInt64(1_000_000_000) << exponent, Self.maximumReconnectNanoseconds)
        scheduleConnect(after: delay)
    }

    private func disconnect(
        code: URLSessionWebSocketTask.CloseCode,
        reason: String,
        reconnect: Bool
    ) {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        let socket = webSocket
        webSocket = nil
        connectionGeneration = nil
        socket?.cancel(with: code, reason: Data(reason.prefix(120).utf8))
        state.connected = false
        state.registered = false
        if reconnect, state.running, state.applicationActive { scheduleConnect(after: 0) }
    }

    private func statusDictionary(_ value: FabushiAppAgentSurface.Status) -> [String: Any] {
        [
            "version": value.version,
            "appId": value.appId,
            "platform": value.platform,
            "available": value.available,
            "screen": value.screen,
            "generation": value.generation,
        ]
    }

    private func snapshotDictionary(
        _ value: FabushiAppAgentSurface.Snapshot,
        maximumElements: Int = 500
    ) -> [String: Any] {
        [
            "version": value.version,
            "appId": value.appId,
            "platform": value.platform,
            "screen": value.screen,
            "generation": value.generation,
            "elementCount": value.elements.count,
            "elements": elementDictionaries(Array(value.elements.prefix(maximumElements))),
        ]
    }

    private func assertionDictionary(_ value: FabushiAppAgentSurface.Assertion) -> [String: Any] {
        [
            "passed": value.passed,
            "screen": value.screen,
            "generation": value.generation,
            "matches": elementDictionaries(value.matches),
            "failures": value.failures,
        ]
    }

    private func elementDictionaries(_ elements: [FabushiAppAgentSurface.Element]) -> [[String: Any]] {
        elements.map { element in
            var row: [String: Any] = [
                "agentId": element.agentId,
                "role": element.role,
                "name": element.name,
                "visible": element.visible,
                "enabled": element.enabled,
                "sensitive": element.sensitive,
            ]
            if let valuePresent = element.valuePresent { row["valuePresent"] = valuePresent }
            if let valueLength = element.valueLength { row["valueLength"] = valueLength }
            return row
        }
    }

    private func summary(toolName: String, result: [String: Any]) -> String {
        switch toolName {
        case "fabushi.app.status":
            return "iOS Fabushi App MCP availability: \(result["available"] as? Bool ?? false)."
        case "fabushi.app.snapshot":
            return "Read iOS Fabushi semantic surface generation \(result["generation"] ?? 0)."
        case "fabushi.app.find":
            return "Found \(result["count"] ?? 0) iOS Fabushi semantic elements."
        case "fabushi.app.action":
            return "Completed iOS Fabushi semantic action."
        case "fabushi.app.wait":
            return "iOS Fabushi semantic wait passed=\(result["passed"] as? Bool ?? false)."
        default:
            return "iOS Fabushi semantic assertion passed=\(result["passed"] as? Bool ?? false)."
        }
    }

    private func optionalString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func unsignedInteger(_ value: Any?) -> UInt64? {
        if let value = value as? UInt64 { return value }
        if let value = value as? Int, value >= 0 { return UInt64(value) }
        if let value = value as? NSNumber, value.int64Value >= 0 { return value.uint64Value }
        return nil
    }

    private func randomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AgentError.invalidArguments("secure random generation failed")
        }
        return Data(bytes)
    }

    private func architectureName() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private func safeError(_ error: Error) -> String {
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return String(raw.replacingOccurrences(
            of: #"(?i)(bearer|token|password|secret)\s*[:=]?\s*[^\s,;]+"#,
            with: "$1=<redacted>",
            options: .regularExpression
        ).prefix(500))
    }
}

private extension Data {
    var base64URLString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
