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
        app.buttons[UITestIDs.Library.importButton]
    }

    var recordButton: XCUIElement {
        app.buttons[UITestIDs.Library.recordButton]
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
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()
        return self
    }

    @discardableResult
    func tapRecord() -> Self {
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()
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
