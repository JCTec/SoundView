import XCTest

struct SeparationViewRobot {
    let app: XCUIApplication

    var screen: XCUIElement {
        app.otherElements[UITestIDs.Separation.screen]
    }

    var cancelButton: XCUIElement {
        app.buttons[UITestIDs.Separation.cancel]
    }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 8) -> Self {
        XCTAssertTrue(screen.waitForExistence(timeout: timeout), "Separation screen missing")
        return self
    }

    @discardableResult
    func tapCancel() -> Self {
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()
        return self
    }
}
