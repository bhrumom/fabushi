import Foundation

final class MahayanaHost: @unchecked Sendable {
    struct JSONResult: @unchecked Sendable {
        let value: Any
    }

    enum HostError: LocalizedError {
        case initializationFailed
        case invalidResponse
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .initializationFailed: return "Mahayana Rust Host 初始化失败"
            case .invalidResponse: return "Mahayana Rust Host 返回了无效响应"
            case .requestFailed(let message): return message
            }
        }
    }

    private let queue = DispatchQueue(label: "com.ombhrum.fabushi.mahayana-host", qos: .userInitiated)
    private var handle: UnsafeMutableRawPointer?

    init(appDataDirectory: URL) throws {
        try FileManager.default.createDirectory(at: appDataDirectory, withIntermediateDirectories: true)
        handle = appDataDirectory.path.withCString { mahayana_app_host_create($0) }
        guard handle != nil else { throw HostError.initializationFailed }
    }

    deinit {
        if let handle { mahayana_app_host_destroy(handle) }
    }

    func request(method: String, params: [String: Any] = [:]) async throws -> JSONResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    continuation.resume(
                        returning: JSONResult(value: try requestSync(method: method, params: params))
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func requestSync(method: String, params: [String: Any]) throws -> Any {
        guard let handle else { throw HostError.initializationFailed }
        let data = try JSONSerialization.data(withJSONObject: ["method": method, "params": params])
        guard let request = String(data: data, encoding: .utf8) else { throw HostError.invalidResponse }
        let pointer = request.withCString { mahayana_app_host_dispatch_with_handle(handle, $0) }
        guard let pointer else { throw HostError.invalidResponse }
        defer { mahayana_app_host_free_string(pointer) }
        let responseString = String(cString: pointer)
        guard let responseData = responseString.data(using: .utf8),
              let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        else { throw HostError.invalidResponse }
        guard response["ok"] as? Bool == true else {
            throw HostError.requestFailed(response["error"] as? String ?? "Mahayana Host 请求失败")
        }
        return response["result"] ?? NSNull()
    }
}
