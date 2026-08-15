import Foundation
import Observation

struct MarketplacePlugin: Identifiable, Equatable {
    let pluginId: String
    let displayName: String
    let description: String
    let latestVersion: String?
    var id: String { pluginId }
}

struct PluginPermissionRequest: Identifiable, Equatable {
    let pluginId: String
    let runtime: String
    let permissions: [String]
    var id: String { pluginId }
}

@MainActor
@Observable
final class MarketplaceModel {
    var query = ""
    var message = "Mahayana Rust Host 正在启动"
    var loading = false
    var installingPluginId: String?
    var plugins: [MarketplacePlugin] = []
    var permissionRequest: PluginPermissionRequest?
    var featureHostSmokeStatus: String?

    private let host: MahayanaHost

    init(host: MahayanaHost) {
        self.host = host
    }

    func runFeatureHostSmokeIfRequested() async {
        guard ProcessInfo.processInfo.environment["FABUSHI_FEATURE_HOST_SMOKE"] == "1" else { return }
        featureHostSmokeStatus = "running"
        do {
            let infoResult = try await host.request(method: "feature.info")
            guard let info = infoResult.value as? [String: Any],
                  info["platform"] as? String == "ios",
                  let protocolVersion = info["protocolVersion"] as? String,
                  !protocolVersion.isEmpty
            else {
                throw MahayanaHost.HostError.invalidResponse
            }

            _ = try await host.request(method: "feature.auth.status")
            _ = try await host.request(method: "feature.auth.providers")

            let requestId = "ios-app-smoke"
            let acceptedResult = try await host.request(
                method: "feature.execute",
                params: [
                    "command": [
                        "type": "automation.list",
                        "requestId": requestId,
                    ],
                ]
            )
            guard let accepted = acceptedResult.value as? [String: Any],
                  accepted["requestId"] as? String == requestId
            else {
                throw MahayanaHost.HostError.invalidResponse
            }
            featureHostSmokeStatus = "passed"
        } catch {
            featureHostSmokeStatus = "failed: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            let result = try await host.request(
                method: "marketplace.browse",
                params: ["query": query.isEmpty ? NSNull() : query, "platform": "ios"]
            )
            let object = result.value as? [String: Any]
            let rows = object?["plugins"] as? [[String: Any]] ?? []
            plugins = rows.compactMap { item in
                guard let id = item["pluginId"] as? String, !id.isEmpty else { return nil }
                return MarketplacePlugin(
                    pluginId: id,
                    displayName: item["displayName"] as? String ?? id,
                    description: item["description"] as? String ?? "无描述",
                    latestVersion: item["latestVersion"] as? String
                )
            }
            message = "原生 iOS · Rust Host 已连接"
        } catch {
            message = "市场加载失败：\(error.localizedDescription)"
        }
    }

    func install(_ plugin: MarketplacePlugin) async {
        guard let version = plugin.latestVersion, !version.isEmpty else {
            message = "\(plugin.pluginId) 没有可安装版本"
            return
        }
        installingPluginId = plugin.pluginId
        message = "正在安装 \(plugin.pluginId)@\(version)…"
        do {
            let metadata = try await host.request(
                method: "marketplace.release",
                params: ["pluginId": plugin.pluginId, "version": version]
            )
            guard let release = (metadata.value as? [String: Any])?["releaseManifest"] as? [String: Any] else {
                throw MahayanaHost.HostError.invalidResponse
            }
            let installed = try await host.request(
                method: "plugin.install",
                params: ["release": release, "platform": "ios"]
            )
            guard let object = installed.value as? [String: Any] else {
                throw MahayanaHost.HostError.invalidResponse
            }
            let pluginId = object["pluginId"] as? String ?? plugin.pluginId
            let runtime = object["runtime"] as? String ?? "unknown"
            let permissions = object["requestedPermissions"] as? [String] ?? []
            installingPluginId = nil
            if permissions.isEmpty {
                await startPortableRuntime(pluginId: pluginId, runtime: runtime)
            } else {
                permissionRequest = PluginPermissionRequest(
                    pluginId: pluginId,
                    runtime: runtime,
                    permissions: permissions
                )
                message = "\(pluginId) 请求 \(permissions.count) 项权限"
            }
        } catch {
            installingPluginId = nil
            message = "安装失败：\(error.localizedDescription)"
        }
    }

    func approvePermissions() async {
        guard let request = permissionRequest else { return }
        permissionRequest = nil
        installingPluginId = request.pluginId
        message = "正在授权 \(request.pluginId)…"
        do {
            for permission in request.permissions {
                _ = try await host.request(
                    method: "plugin.permission.grant",
                    params: ["pluginId": request.pluginId, "permission": permission]
                )
            }
            installingPluginId = nil
            await startPortableRuntime(pluginId: request.pluginId, runtime: request.runtime)
        } catch {
            installingPluginId = nil
            message = "授权失败：\(error.localizedDescription)"
        }
    }

    func denyPermissions() {
        guard let request = permissionRequest else { return }
        permissionRequest = nil
        installingPluginId = nil
        message = "\(request.pluginId) 已安装，但权限未授权"
    }

    private func startPortableRuntime(pluginId: String, runtime: String) async {
        guard ["deepseek-js", "javascript", "cordis-js"].contains(runtime) else {
            message = "\(pluginId) 已安装 · \(runtime)"
            return
        }
        installingPluginId = pluginId
        do {
            let compatibility = try await host.request(
                method: "plugin.compatibility",
                params: ["pluginId": pluginId]
            )
            guard let object = compatibility.value as? [String: Any], object["portableCompatible"] as? Bool == true else {
                throw MahayanaHost.HostError.requestFailed("插件不满足移动端 portable runtime 约束")
            }
            _ = try await host.request(
                method: "runtime.start",
                params: ["pluginId": pluginId, "config": [String: Any]()]
            )
            message = "\(pluginId) 已安装并启动 · \(runtime)"
        } catch {
            message = "\(pluginId) 已安装但启动失败：\(error.localizedDescription)"
        }
        installingPluginId = nil
    }
}
