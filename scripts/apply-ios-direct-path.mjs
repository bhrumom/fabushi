import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const directPath = resolve(process.cwd(), "mobile/ios/Fabushi/FabushiDeviceDirectPath.swift");
const agentPath = resolve(process.cwd(), "mobile/ios/Fabushi/FabushiDeviceMeshAgent.swift");

let direct = readFileSync(directPath, "utf8");
let agent = readFileSync(agentPath, "utf8");
let changed = false;

function replace(target, before, after, marker) {
  if (target.text.includes(marker)) return;
  if (!target.text.includes(before)) throw new Error(`Missing iOS direct-path anchor: ${marker}`);
  target.text = target.text.replace(before, after);
  changed = true;
}

const directTarget = { text: direct };
replace(directTarget,
  "import Foundation\nimport Network\n",
  "import CryptoKit\nimport Foundation\nimport Network\n",
  "import CryptoKit\n",
);
replace(directTarget,
  "        let ready = CheckedContinuationBox<Void>()\n        listener.stateUpdateHandler = { state in\n            switch state {\n            case .ready:\n                ready.resume(returning: ())\n            case .failed(let error):\n                ready.resume(throwing: error)\n            default:\n                break\n            }\n        }\n        listener.start(queue: queue)\n        try await ready.value()\n",
  "        try await withCheckedThrowingContinuation { continuation in\n            let box = CheckedContinuationBox<Void>(continuation)\n            listener.stateUpdateHandler = { state in\n                switch state {\n                case .ready: box.resume(returning: ())\n                case .failed(let error): box.resume(throwing: error)\n                default: break\n                }\n            }\n            listener.start(queue: queue)\n        } // GBF-412 await UDP listener readiness\n",
  "// GBF-412 await UDP listener readiness",
);
replace(directTarget,
  "        guard let key = SecKeyCreateWithData(representation as CFData, attributes as CFDictionary, &error) else {\n            throw error?.takeRetainedValue() ?? DirectPathError.invalidPublicKey as CFError\n        }\n",
  "        guard let key = SecKeyCreateWithData(representation as CFData, attributes as CFDictionary, &error) else {\n            if let error { throw error.takeRetainedValue() }\n            throw DirectPathError.invalidPublicKey\n        } // GBF-412 valid SecKey error propagation\n",
  "// GBF-412 valid SecKey error propagation",
);
replace(directTarget,
  "        let digest = SHA256Digest.hash(Data(\"\\(kty):\\(crv):\\(x):\\(y)\".utf8))\n        return digest.base64URLString.prefix(32).description\n",
  "        let digest = Data(SHA256.hash(data: Data(\"\\(kty):\\(crv):\\(x):\\(y)\".utf8)))\n        return digest.base64URLString.prefix(32).description // GBF-412 CryptoKit fingerprint\n",
  "// GBF-412 CryptoKit fingerprint",
);
const shaHelper = `\nprivate enum SHA256Digest {\n    static func hash(_ data: Data) -> Data {\n        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))\n        data.withUnsafeBytes { buffer in\n            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)\n        }\n        return Data(digest)\n    }\n}\n`;
if (directTarget.text.includes(shaHelper)) {
  directTarget.text = directTarget.text.replace(shaHelper, "\n");
  changed = true;
}
direct = directTarget.text;

const agentTarget = { text: agent };
replace(agentTarget,
  "    private var webSocket: URLSessionWebSocketTask?\n    private var connectionGeneration: String?\n",
  "    private var webSocket: URLSessionWebSocketTask?\n    private var connectionGeneration: String?\n    private var directPath: FabushiDeviceDirectPath? // GBF-412 iOS direct path\n",
  "// GBF-412 iOS direct path",
);
replace(agentTarget,
  "            let generation = try randomData(count: 24).base64URLString\n            let request = try gatewayRequest(accessToken: account.accessToken)\n",
  "            let generation = try randomData(count: 24).base64URLString\n            directPath?.stop()\n            let direct = FabushiDeviceDirectPath(deviceId: account.deviceId, generation: generation, identity: identity)\n            try await direct.start()\n            directPath = direct // GBF-412 iOS direct endpoint start\n            let request = try gatewayRequest(accessToken: account.accessToken)\n",
  "// GBF-412 iOS direct endpoint start",
);
replace(agentTarget,
  "        return [\n            \"type\": \"register\",\n",
  "        var registration: [String: Any] = [\n            \"type\": \"register\",\n",
  "var registration: [String: Any] = [",
);
replace(agentTarget,
  "            \"mesh\": mesh,\n        ]\n    }\n\n    private func beginReceiveLoop",
  "            \"mesh\": mesh,\n        ]\n        if let directPath {\n            registration[\"direct\"] = directPath.registrationJSON()\n            var directMesh = mesh\n            directMesh[\"supportedPaths\"] = [\"direct-udp\", \"relay\"]\n            directMesh[\"preferredPath\"] = \"direct-udp\"\n            registration[\"mesh\"] = directMesh\n        } // GBF-412 iOS publish direct candidates\n        return registration\n    }\n\n    private func beginReceiveLoop",
  "// GBF-412 iOS publish direct candidates",
);
replace(agentTarget,
  "                    try await self.send([\n                        \"type\": \"heartbeat\",\n                        \"at\": Int64(Date().timeIntervalSince1970 * 1_000),\n                        \"mesh\": [\n                            \"activePath\": \"relay\",\n                            \"posture\": self.posture(appState: self.surface.status().available ? \"foreground\" : \"foreground-unavailable\"),\n                        ],\n                    ], over: socket)\n",
  "                    var heartbeat: [String: Any] = [\n                        \"type\": \"heartbeat\",\n                        \"at\": Int64(Date().timeIntervalSince1970 * 1_000),\n                        \"mesh\": [\n                            \"activePath\": \"relay\",\n                            \"posture\": self.posture(appState: self.surface.status().available ? \"foreground\" : \"foreground-unavailable\"),\n                        ],\n                    ]\n                    if let directPath = self.directPath { heartbeat[\"direct\"] = directPath.registrationJSON() } // GBF-412 iOS direct heartbeat\n                    try await self.send(heartbeat, over: socket)\n",
  "// GBF-412 iOS direct heartbeat",
);
replace(agentTarget,
  "        case \"call\":\n            try await handleCall(object, from: socket)\n",
  "        case \"direct_peer_map\":\n            guard object[\"version\"] as? String == FabushiDeviceDirectPath.protocolVersion,\n                  let directPath, let peers = object[\"peers\"] as? [[String: Any]] else { return }\n            directPath.updatePeers(peers)\n            directPath.probeAll { [weak self, weak socket] health in\n                guard let self, let socket, self.webSocket === socket else { return }\n                Task { @MainActor in\n                    try? await self.send([\n                        \"type\": \"direct_path_health\",\n                        \"targetDeviceId\": health.targetDeviceId,\n                        \"candidateId\": health.candidateId,\n                        \"reachable\": health.reachable,\n                        \"latencyMs\": health.latencyMs,\n                        \"loss\": health.loss,\n                    ], over: socket)\n                }\n            } // GBF-412 iOS direct peer probing\n        case \"call\":\n            try await handleCall(object, from: socket)\n",
  "// GBF-412 iOS direct peer probing",
);
replace(agentTarget,
  "        heartbeatTask?.cancel()\n        heartbeatTask = nil\n        let socket = webSocket\n",
  "        heartbeatTask?.cancel()\n        heartbeatTask = nil\n        directPath?.stop()\n        directPath = nil // GBF-412 iOS direct lifecycle cleanup\n        let socket = webSocket\n",
  "// GBF-412 iOS direct lifecycle cleanup",
);
agent = agentTarget.text;

if (changed) {
  writeFileSync(directPath, direct);
  writeFileSync(agentPath, agent);
}
console.log(changed ? "Applied iOS direct path integration and compile fixes." : "iOS direct path integration already applied.");
