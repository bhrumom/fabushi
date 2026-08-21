import SwiftUI

@main
struct FabushiApp: App {
    @State private var model: MarketplaceModel

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.ombhrum.fabushi", isDirectory: true)
        do {
            #if DEBUG
            let featureHostTest = ProcessInfo.processInfo.environment["FABUSHI_FEATURE_HOST_SMOKE"] == "1"
            #else
            let featureHostTest = false
            #endif
            _model = State(initialValue: MarketplaceModel(
                host: try MahayanaHost(appDataDirectory: base, featureHostTest: featureHostTest)
            ))
        } catch {
            fatalError("Failed to initialize Mahayana Host: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task {
                    await model.runFeatureHostSmokeIfRequested()
                    await model.refresh()
                }
                .onOpenURL { url in
                    consumeDeepLink(url)
                }
        }
    }

    @MainActor
    private func consumeDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "fabushi",
              url.user == nil,
              url.password == nil,
              url.port == nil
        else { return }

        let host = url.host?.lowercased() ?? ""
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        switch host {
        case "auth":
            guard parts.first == "complete",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { return }
            let params = Dictionary(uniqueKeysWithValues: components.queryItems?.compactMap { item in
                item.value.map { (item.name, $0) }
            } ?? [])
            let attemptId = params["attemptId"] ?? ""
            let status = (params["status"] ?? "completed").lowercased()
            guard attemptId.range(of: "^[A-Za-z0-9_-]{8,96}$", options: .regularExpression) != nil,
                  ["completed", "cancelled", "failed"].contains(status)
            else { return }
            model.message = status == "completed" ? "登录授权已完成，正在同步账号状态" : "登录授权状态：\(status)"
            if status == "completed" {
                Task { await model.refresh() }
            }
        case "agent":
            guard let agentId = parts.first, !agentId.isEmpty, agentId.count <= 200 else { return }
            model.message = "已接收智能体链接：\(agentId)"
        case "settings", "feedback", "about", "widgets", "onboarding":
            model.message = "已接收应用链接：\(host)"
        default:
            return
        }
    }
}
