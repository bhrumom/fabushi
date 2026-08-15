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
    func testCoreControlsExposeStableAccessibilityIdentifiers() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["app-shell"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["runtime-badge"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["host-status"].waitForExistence(timeout: 5)
        )

        let search = app.textFields["marketplace-search"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("telegram")

        let submit = app.buttons["marketplace-search-submit"]
        XCTAssertTrue(submit.exists)
        submit.tap()
    }
}
