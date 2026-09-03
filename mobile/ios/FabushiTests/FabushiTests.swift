import XCTest
@testable import Fabushi

final class FabushiTests: XCTestCase {
    func testMarketplacePluginIdentityIsStable() {
        let plugin = MarketplacePlugin(
            pluginId: "example.plugin",
            displayName: "示例插件",
            description: "描述",
            latestVersion: "1.0.0",
            tools: []
        )
        XCTAssertEqual(plugin.id, "example.plugin")
        XCTAssertEqual(plugin.latestVersion, "1.0.0")
    }

    @MainActor
    func testAppAgentSurfaceUsesStableToolsAndRejectsStaleSensitiveWrites() throws {
        XCTAssertEqual(FabushiAppAgentSurface.toolNames, [
            "fabushi.app.status",
            "fabushi.app.snapshot",
            "fabushi.app.find",
            "fabushi.app.action",
            "fabushi.app.wait",
            "fabushi.app.assert",
        ])
        let surface = FabushiAppAgentSurface(appId: "fabushi.ios.test")
        var invoked = false
        let snapshot = try surface.publish(
            screen: "login",
            elements: [
                .init(agentId: "login-submit", role: "button", name: "登录"),
                .init(agentId: "login-password", role: "textbox", name: "密码", sensitive: true),
            ],
            actions: [
                "login-submit": .init(allowed: ["invoke"]) { _ in invoked = true },
                "login-password": .init(allowed: ["setValue"]) { _ in },
            ]
        )
        XCTAssertTrue(surface.status().available)
        XCTAssertEqual(surface.find(role: "button").map(\.agentId), ["login-submit"])
        let after = try surface.perform(expectedGeneration: snapshot.generation, agentId: "login-submit", action: "invoke")
        XCTAssertTrue(invoked)
        XCTAssertGreaterThan(after.generation, snapshot.generation)
        XCTAssertThrowsError(try surface.perform(
            expectedGeneration: snapshot.generation,
            agentId: "login-submit",
            action: "invoke"
        ))
        XCTAssertThrowsError(try surface.perform(
            expectedGeneration: after.generation,
            agentId: "login-password",
            action: "setValue",
            value: "secret"
        ))
        XCTAssertTrue(surface.assertState(screen: "login", agentId: "login-submit").passed)
    }

}
