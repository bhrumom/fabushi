import XCTest

final class FabushiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCompleteFeatureHostUserJourneyInAppProcess() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FABUSHI_FEATURE_HOST_SMOKE"] = "1"
        app.launch()

        let smoke = app.descendants(matching: .any)["feature-host-smoke"]
        XCTAssertTrue(smoke.waitForExistence(timeout: 15))
        let finished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR label BEGINSWITH %@", "passed", "failed:"),
            object: smoke
        )
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 90), .completed)
        XCTAssertEqual(smoke.label, "passed", "FeatureHost smoke result: \(smoke.label)")
    }

    @MainActor
    func testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["app-shell"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["profile-avatar"].exists)
        XCTAssertTrue(app.buttons["home-search-button"].exists)
        XCTAssertTrue(app.buttons["home-add-button"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["conversation-list"].exists)
        XCTAssertFalse(app.staticTexts["Chief of Staff"].exists)
        app.buttons["home-add-button"].tap()
        let newDirect = app.buttons["新建私聊"]
        XCTAssertTrue(newDirect.waitForExistence(timeout: 5))
        newDirect.tap()
        let composeName = app.textFields["compose-name"]
        XCTAssertTrue(composeName.waitForExistence(timeout: 5))
        composeName.tap()
        composeName.typeText("测试联系人")
        app.buttons["compose-create"].tap()
        XCTAssertTrue(app.navigationBars["测试联系人"].waitForExistence(timeout: 5))

        openRemoteComputer(in: app)
        let remoteComputer = app.descendants(matching: .any)["remote-computer-surface"]
        XCTAssertTrue(remoteComputer.waitForExistence(timeout: 10))
        tapSurfaceClose(identifier: "remote-computer-close", in: app)
        XCTAssertTrue(remoteComputer.waitForNonExistence(timeout: 10))

        openMarketplace(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["runtime-badge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["host-status"].exists)

        let search = app.textFields["marketplace-search"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("telegram")
        let submit = app.buttons["marketplace-search-submit"]
        XCTAssertTrue(submit.exists)
        submit.tap()
    }

    @MainActor
    func testMiniAppOpensAndClosesDedicatedWebMcpSurface() throws {
        let app = XCUIApplication()
        app.launch()
        openMarketplace(in: app)

        let open = app.buttons["open-global-dharma"]
        XCTAssertTrue(
            scrollToElement(open, in: app),
            "Expected global-dharma WebMCP open button after scrolling Marketplace"
        )
        open.tap()

        let surface = app.descendants(matching: .any)["miniapp-webmcp-surface"]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))

        // WKWebView's internal DOM accessibility projection is not stable across
        // simulator/WebKit versions. The product already runs a JavaScript WebMCP
        // probe in WKNavigationDelegate.didFinish and projects that result into the
        // native SwiftUI status label. Assert that native readiness projection.
        let connected = app.staticTexts["WebMCP 已连接"]
        let localConnected = app.staticTexts["本地 WebMCP 已连接"]
        let opened = app.staticTexts["WebMCP 页面已打开"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                connected.exists || localConnected.exists || opened.exists
            },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [ready], timeout: 15),
            .completed,
            "Expected the native WebMCP readiness status after WKNavigationDelegate.didFinish"
        )

        tapSurfaceClose(identifier: "miniapp-webmcp-close", in: app)
        XCTAssertTrue(surface.waitForNonExistence(timeout: 10))
    }

    @MainActor
    private func tapSurfaceClose(identifier: String, in app: XCUIApplication) {
        let byIdentifier = app.descendants(matching: .any)[identifier]
        if byIdentifier.waitForExistence(timeout: 5) && byIdentifier.isHittable {
            byIdentifier.tap()
            return
        }

        // SwiftUI can omit a Button's identifier from the simulator accessibility
        // projection while preserving its visible label and tap action.
        let byLabel = app.buttons["返回"]
        XCTAssertTrue(
            byLabel.waitForExistence(timeout: 5),
            "Expected close button \(identifier) or the SwiftUI 返回 label"
        )
        byLabel.tap()
    }

    @MainActor
    private func openMarketplace(in app: XCUIApplication) {
        let profile = app.descendants(matching: .any)["profile-avatar"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        let marketplace = app.buttons["marketplace-entry"]
        XCTAssertTrue(marketplace.waitForExistence(timeout: 5))
        marketplace.tap()
    }

    @MainActor
    private func openRemoteComputer(in app: XCUIApplication) {
        let profile = app.descendants(matching: .any)["profile-avatar"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        let remoteComputer = app.buttons["remote-computer-entry"]
        XCTAssertTrue(remoteComputer.waitForExistence(timeout: 5))
        remoteComputer.tap()
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) -> Bool {
        if element.exists {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return element.exists
    }
}
