import SwiftUI

@main
struct FabushiApp: App {
    @State private var model: MarketplaceModel

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.ombhrum.fabushi", isDirectory: true)
        do {
            _model = State(initialValue: MarketplaceModel(host: try MahayanaHost(appDataDirectory: base)))
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
        }
    }
}
