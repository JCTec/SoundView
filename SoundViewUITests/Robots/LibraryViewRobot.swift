import XCTest

/// 1:1 robot for `LibraryView` / library sidebar.
struct LibraryViewRobot {
    let app: XCUIApplication

    var screen: XCUIElement {
        let library = app.otherElements[UITestIDs.Library.screen]
        if library.exists { return library }
        return app.navigationBars["Library"]
    }

    var importButton: XCUIElement {
        // Prefer buttons, fall back to any (capsule may surface as Other).
        let button = app.buttons[UITestIDs.Library.importButton]
        if button.exists { return button }
        return app.descendants(matching: .any)[UITestIDs.Library.importButton]
    }

    var recordButton: XCUIElement {
        let button = app.buttons[UITestIDs.Library.recordButton]
        if button.exists { return button }
        return app.descendants(matching: .any)[UITestIDs.Library.recordButton]
    }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(
            screen.waitForExistence(timeout: timeout)
                || importButton.waitForExistence(timeout: timeout),
            "Library screen not found"
        )
        return self
    }

    @discardableResult
    func tapImport() -> Self {
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "Import control missing")
        importButton.tap()
        return self
    }

    @discardableResult
    func tapRecord() -> Self {
        // Prefer a11y id; fall back to visible title (same strategy as ScreenshotReviewTests).
        let byID = app.descendants(matching: .any)[UITestIDs.Library.recordButton]
        if byID.waitForExistence(timeout: 3) {
            byID.tap()
            return self
        }
        app.swipeUp()
        if byID.waitForExistence(timeout: 2) {
            byID.tap()
            return self
        }
        let byTitle = app.buttons["Record"].firstMatch
        XCTAssertTrue(byTitle.waitForExistence(timeout: 5), "Record control missing")
        byTitle.tap()
        return self
    }

    @discardableResult
    func tapSong(id: String) -> Self {
        let row = app.buttons[UITestIDs.Library.row(id)]
        let desc = app.descendants(matching: .any)[UITestIDs.Library.row(id)]
        let target = row.exists ? row : desc
        XCTAssertTrue(target.waitForExistence(timeout: 8), "Song row \(id) missing")
        target.tap()
        return self
    }
}
