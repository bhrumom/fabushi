import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "mobile/ios/Fabushi/FabushiDeviceDirectPath.swift");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing Swift 6 direct-path anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  "        try await withCheckedThrowingContinuation { continuation in\n            let box = CheckedContinuationBox<Void>(continuation)\n",
  "        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in\n            let box = CheckedContinuationBox<Void>(continuation)\n",
  "// GBF-412 Swift 6 start continuation",
);
source = source.replace(
  "            connection.start(queue: queue)\n        }\n    }\n\n    private func send(_ object: [String: Any], over connection: NWConnection) async throws {",
  "            connection.start(queue: queue)\n        } // GBF-412 Swift 6 start continuation\n    }\n\n    private func send(_ object: [String: Any], over connection: NWConnection) async throws {",
);

replaceOnce(
  "        try await withCheckedThrowingContinuation { continuation in\n            connection.send(content: data, completion: .contentProcessed { error in\n",
  "        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in\n            connection.send(content: data, completion: .contentProcessed { error in\n",
  "// GBF-412 Swift 6 send continuation",
);
source = source.replace(
  "            })\n        }\n    }\n\n    private func receiveDatagram(_ connection: NWConnection, timeoutNanoseconds: UInt64) async throws -> [String: Any] {",
  "            })\n        } // GBF-412 Swift 6 send continuation\n    }\n\n    private func receiveDatagram(_ connection: NWConnection, timeoutNanoseconds: UInt64) async throws -> [String: Any] {",
);

replaceOnce(
  `        try await withThrowingTaskGroup(of: [String: Any].self) { group in
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
`,
  `        let data = try await withThrowingTaskGroup(of: Data.self) { group in
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
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DirectPathError.invalidPacket
        }
        return object // GBF-412 Swift 6 Sendable datagram boundary
`,
  "// GBF-412 Swift 6 Sendable datagram boundary",
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied Swift 6 direct-path concurrency fixes." : "Swift 6 direct-path concurrency fixes already applied.");
