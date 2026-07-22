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

    var exportSheet: XCUIElement {
        app.otherElements[UITestIDs.Stem.exportSheet]
    }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(screen.waitForExistence(timeout: timeout), "Stem screen not found")
        return self
    }

    @discardableResult
    func tapExport() -> Self {
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export button missing")
        exportButton.tap()
        return self
    }

    @discardableResult
    func waitForExportSheet(timeout: TimeInterval = 8) -> Self {
        XCTAssertTrue(exportSheet.waitForExistence(timeout: timeout), "Export sheet did not present")
        return self
    }

    @discardableResult
    func selectExportOption(_ id: String) -> Self {
        let option = app.buttons[UITestIDs.Stem.exportOption(id)]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Export option \(id) missing")
        option.tap()
        return self
    }

    @discardableResult
    func runExport() -> Self {
        let run = app.buttons[UITestIDs.Stem.exportRun]
        XCTAssertTrue(run.waitForExistence(timeout: 5), "Export run button missing")
        run.tap()
        return self
    }

    /// The share affordance appears once the export finishes.
    @discardableResult
    func waitForShare(timeout: TimeInterval = 30) -> Self {
        let share = app.buttons[UITestIDs.Stem.exportShare]
        XCTAssertTrue(share.waitForExistence(timeout: timeout), "Share affordance never appeared")
        return self
    }
}
