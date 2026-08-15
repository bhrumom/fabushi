import XCTest

final class FabushiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreControlsExposeStableAccessibilityIdentifiers() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["app-shell"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["runtime-badge"].exists)
        XCTAssertTrue(app.staticTexts["host-status"].exists)

        let search = app.textFields["marketplace-search"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("telegram")

        let submit = app.buttons["marketplace-search-submit"]
        XCTAssertTrue(submit.exists)
        submit.tap()
    }
}
