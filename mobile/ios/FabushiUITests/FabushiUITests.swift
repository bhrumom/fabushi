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
        XCTAssertTrue(app.staticTexts["Chief of Staff"].waitForExistence(timeout: 5))

        app.buttons["home-search-button"].tap()
        let homeSearch = app.textFields["home-search-field"]
        XCTAssertTrue(homeSearch.waitForExistence(timeout: 5))
        homeSearch.tap()
        homeSearch.typeText("Chief")
        XCTAssertTrue(app.staticTexts["Chief of Staff"].exists)

        openRemoteComputer(in: app)
        let remoteComputer = app.descendants(matching: .any)["remote-computer-surface"]
        XCTAssertTrue(remoteComputer.waitForExistence(timeout: 10))
        let remoteComputerClose = app.descendants(matching: .any)["remote-computer-close"]
        XCTAssertTrue(remoteComputerClose.waitForExistence(timeout: 5))
        remoteComputerClose.tap()
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

        let close = app.descendants(matching: .any)["miniapp-webmcp-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(surface.waitForNonExistence(timeout: 10))
    }

    @MainActor
    private func openMarketplace(in app: XCUIApplication) {
        let add = app.buttons["home-add-button"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let marketplace = app.buttons["marketplace-entry"]
        XCTAssertTrue(marketplace.waitForExistence(timeout: 5))
        marketplace.tap()
    }

    @MainActor
    private func openRemoteComputer(in app: XCUIApplication) {
        let add = app.buttons["home-add-button"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
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
