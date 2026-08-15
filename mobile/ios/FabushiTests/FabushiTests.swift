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
}
