import XCTest

struct StemViewRobot {
    let app: XCUIApplication

    var screen: XCUIElement {
        let stem = app.otherElements[UITestIDs.Stem.screen]
        if stem.exists { return stem }
        return app.otherElements[UITestIDs.Stem.desk]
    }

    var exportButton: XCUIElement {
        app.buttons[UITestIDs.Stem.export]
    }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(screen.waitForExistence(timeout: timeout), "Stem screen not found")
        return self
    }
}
