import XCTest
@testable import Fabushi

final class FabushiTests: XCTestCase {
    func testMarketplacePluginIdentityIsStable() {
        let plugin = MarketplacePlugin(
            pluginId: "example.plugin",
            displayName: "示例插件",
            description: "描述",
            latestVersion: "1.0.0"
        )
        XCTAssertEqual(plugin.id, "example.plugin")
        XCTAssertEqual(plugin.latestVersion, "1.0.0")
    }

    func testNativeBridgeExecutesReadOnlyFeatureHostJourneys() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fabushi-feature-host-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let host = try MahayanaHost(appDataDirectory: root)
        let infoResult = try await host.request(method: "feature.info")
        let info = try XCTUnwrap(infoResult.value as? [String: Any])
        XCTAssertEqual(info["platform"] as? String, "ios")
        XCTAssertFalse((info["protocolVersion"] as? String ?? "").isEmpty)

        for (index, type) in ["automation.list", "group.list", "teach.status"].enumerated() {
            let requestId = "ios-native-\(index)"
            let acceptedResult = try await host.request(
                method: "feature.execute",
                params: [
                    "command": [
                        "type": type,
                        "requestId": requestId,
                    ],
                ]
            )
            let accepted = try XCTUnwrap(acceptedResult.value as? [String: Any])
            XCTAssertEqual(accepted["requestId"] as? String, requestId)

            let event = try await host.request(method: "feature.receive").value
            XCTAssertFalse(event is NSNull)
        }
    }
}
