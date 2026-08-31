import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "mobile/ios/Fabushi/FabushiDeviceMeshAgent.swift");
let source = readFileSync(path, "utf8");
let changed = false;
function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing iOS direct RPC anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  '    private var directPath: FabushiDeviceDirectPath? // GBF-412 iOS direct path\n',
  '    private var directPath: FabushiDeviceDirectPath? // GBF-412 iOS direct path\n' +
    '    private struct InvocationOutcome: Sendable { let ok: Bool; let data: Data; let error: String? }\n' +
    '    private var invocationCache: [String: InvocationOutcome] = [:]\n' +
    '    private var invocationTasks: [String: Task<InvocationOutcome, Never>] = [:] // GBF-412 iOS exactly-once calls\n',
  '// GBF-412 iOS exactly-once calls',
);

replaceOnce(
  '            directPath.updatePeers(peers)\n            directPath.probeAll { [weak self, weak socket] health in\n',
  '            directPath.updatePeers(peers)\n' +
    '            directPath.configureRPC(accountBinding: object["accountBinding"] as? String) { [weak self] invocationId, toolName, arguments in\n' +
    '                guard let self else { throw AgentError.invalidArguments("device agent stopped") }\n' +
    '                return try await self.executeInvocation(invocationId: invocationId, toolName: toolName, arguments: arguments)\n' +
    '            } // GBF-412 iOS account-bound direct RPC\n' +
    '            directPath.probeAll { [weak self, weak socket] health in\n',
  '// GBF-412 iOS account-bound direct RPC',
);

replaceOnce(
  '        case "call":\n            try await handleCall(object, from: socket)\n',
  '        case "direct_forward_call":\n' +
    '            try await handleDirectForward(object, from: socket) // GBF-412 iOS direct forwarding\n' +
    '        case "call":\n' +
    '            try await handleCall(object, from: socket)\n',
  '// GBF-412 iOS direct forwarding',
);

replaceOnce(
  '    private func handleCall(_ message: [String: Any], from socket: URLSessionWebSocketTask) async throws {\n',
  '    private func handleDirectForward(_ message: [String: Any], from socket: URLSessionWebSocketTask) async throws {\n' +
    '        let requestId = String((message["requestId"] as? String ?? "").prefix(128))\n' +
    '        let invocationId = String((message["invocationId"] as? String ?? requestId).prefix(128))\n' +
    '        let targetDeviceId = String((message["targetDeviceId"] as? String ?? "").prefix(128))\n' +
    '        let targetGeneration = String((message["targetGeneration"] as? String ?? "").prefix(128))\n' +
    '        let toolName = String((message["toolName"] as? String ?? "").prefix(128))\n' +
    '        let arguments = message["arguments"] as? [String: Any] ?? [:]\n' +
    '        guard let directPath, let peer = directPath.peer(deviceId: targetDeviceId),\n' +
    '              peer.generation == targetGeneration, let candidate = directPath.preferredCandidate(for: peer) else {\n' +
    '            try await send(["type": "direct_forward_failed", "requestId": requestId, "invocationId": invocationId, "error": "No authenticated iOS direct route is available."], over: socket)\n' +
    '            return\n' +
    '        }\n' +
    '        do {\n' +
    '            let payload = try await directPath.call(\n' +
    '                peer: peer, candidate: candidate, toolName: toolName, arguments: arguments, invocationId: invocationId,\n' +
    '                timeoutNanoseconds: UInt64(max(500, min(5_000, integer(message["timeoutMs"]) ?? 2_500))) * 1_000_000\n' +
    '            )\n' +
    '            let result = payload["result"] as? [String: Any] ?? [:]\n' +
    '            try await send(["type": "result", "requestId": requestId, "invocationId": invocationId, "ok": true, "route": "direct-udp", "result": result], over: socket)\n' +
    '        } catch {\n' +
    '            try await send(["type": "direct_forward_failed", "requestId": requestId, "invocationId": invocationId, "error": safeError(error)], over: socket)\n' +
    '        }\n' +
    '    } // GBF-412 iOS peer direct call path\n\n' +
    '    private func executeInvocation(invocationId: String, toolName: String, arguments: [String: Any]) async throws -> [String: Any] {\n' +
    '        guard invocationId.range(of: #"^[A-Za-z0-9._:-]{16,128}$"#, options: .regularExpression) != nil,\n' +
    '              FabushiAppAgentSurface.toolNames.contains(toolName) else { throw AgentError.unsupportedTool }\n' +
    '        if let cached = invocationCache[invocationId] { return try decodeInvocation(cached) }\n' +
    '        let task: Task<InvocationOutcome, Never>\n' +
    '        if let existing = invocationTasks[invocationId] { task = existing }\n' +
    '        else {\n' +
    '            task = Task { @MainActor [weak self] in\n' +
    '                guard let self else { return InvocationOutcome(ok: false, data: Data(), error: "device agent stopped") }\n' +
    '                do {\n' +
    '                    let structured = try await self.call(toolName: toolName, arguments: arguments)\n' +
    '                    let result: [String: Any] = ["structuredContent": structured, "content": [["type": "text", "text": self.summary(toolName: toolName, result: structured)]]]\n' +
    '                    let data = (try? JSONSerialization.data(withJSONObject: result)) ?? Data()\n' +
    '                    return InvocationOutcome(ok: true, data: data, error: nil)\n' +
    '                } catch { return InvocationOutcome(ok: false, data: Data(), error: self.safeError(error)) }\n' +
    '            }\n' +
    '            invocationTasks[invocationId] = task\n' +
    '        }\n' +
    '        let outcome = await task.value\n' +
    '        invocationTasks.removeValue(forKey: invocationId)\n' +
    '        invocationCache[invocationId] = outcome\n' +
    '        if invocationCache.count > 512, let oldest = invocationCache.keys.first(where: { $0 != invocationId }) { invocationCache.removeValue(forKey: oldest) }\n' +
    '        return try decodeInvocation(outcome)\n' +
    '    } // GBF-412 iOS exactly-once execution boundary\n\n' +
    '    private func decodeInvocation(_ outcome: InvocationOutcome) throws -> [String: Any] {\n' +
    '        guard outcome.ok else { throw AgentError.invalidArguments(outcome.error ?? "device call failed") }\n' +
    '        guard let object = try JSONSerialization.jsonObject(with: outcome.data) as? [String: Any] else { throw AgentError.invalidJSON }\n' +
    '        return object\n' +
    '    }\n\n' +
    '    private func handleCall(_ message: [String: Any], from socket: URLSessionWebSocketTask) async throws {\n',
  '// GBF-412 iOS peer direct call path',
);

replaceOnce(
  '        let arguments = message["arguments"] as? [String: Any] ?? [:]\n        let response: [String: Any]\n',
  '        let arguments = message["arguments"] as? [String: Any] ?? [:]\n' +
    '        let invocationId = String((message["invocationId"] as? String ?? requestId).prefix(128)) // GBF-412 iOS relay invocation id\n' +
    '        let response: [String: Any]\n',
  '// GBF-412 iOS relay invocation id',
);

replaceOnce(
  '            let structured = try await call(toolName: toolName, arguments: arguments)\n            response = [\n                "type": "result",\n                "requestId": requestId,\n                "ok": true,\n                "result": [\n                    "structuredContent": structured,\n                    "content": [["type": "text", "text": summary(toolName: toolName, result: structured)]],\n                ],\n            ]\n',
  '            let result = try await executeInvocation(invocationId: invocationId, toolName: toolName, arguments: arguments)\n' +
    '            response = [\n' +
    '                "type": "result",\n' +
    '                "requestId": requestId,\n' +
    '                "invocationId": invocationId,\n' +
    '                "ok": true,\n' +
    '                "result": result,\n' +
    '            ] // GBF-412 iOS relay shares direct dedupe\n',
  '// GBF-412 iOS relay shares direct dedupe',
);

replaceOnce(
  '                "requestId": requestId,\n                "ok": false,\n                "error": safeError(error),\n',
  '                "requestId": requestId,\n' +
    '                "invocationId": invocationId,\n' +
    '                "ok": false,\n' +
    '                "error": safeError(error), // GBF-412 iOS failed invocation echo\n',
  '// GBF-412 iOS failed invocation echo',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied iOS encrypted direct RPC integration." : "iOS encrypted direct RPC integration already applied.");
