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
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()

        let surface = app.descendants(matching: .any)["miniapp-webmcp-surface"]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["miniapp-webmcp-webview"].exists)

        let close = app.buttons["miniapp-webmcp-close"]
        XCTAssertTrue(close.exists)
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
}
