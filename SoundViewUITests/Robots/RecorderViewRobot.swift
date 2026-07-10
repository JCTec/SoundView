import XCTest

struct RecorderViewRobot {
    let app: XCUIApplication

    var screen: XCUIElement {
        app.otherElements[UITestIDs.Recorder.screen]
    }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 8) -> Self {
        let nav = app.navigationBars["Recorder"]
        XCTAssertTrue(
            screen.waitForExistence(timeout: timeout) || nav.waitForExistence(timeout: timeout),
            "Recorder not presented"
        )
        return self
    }
}
