import XCTest

struct SeparationViewRobot {
    let app: XCUIApplication

    var screen: XCUIElement {
        app.otherElements[UITestIDs.Separation.screen]
    }

    var cancelButton: XCUIElement {
        app.buttons[UITestIDs.Separation.cancel]
    }

    var installModelButton: XCUIElement {
        app.buttons[UITestIDs.Separation.installModel]
    }

    func qualityOption(_ raw: String) -> XCUIElement {
        app.buttons[UITestIDs.QualityPicker.option(raw)]
    }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 8) -> Self {
        XCTAssertTrue(screen.waitForExistence(timeout: timeout), "Separation screen missing")
        return self
    }

    @discardableResult
    func selectQuality(_ raw: String) -> Self {
        let option = qualityOption(raw)
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Quality option \(raw) missing")
        option.tap()
        return self
    }

    @discardableResult
    func tapInstallModel() -> Self {
        XCTAssertTrue(installModelButton.waitForExistence(timeout: 5), "Install-model affordance missing")
        installModelButton.tap()
        return self
    }

    @discardableResult
    func tapCancel() -> Self {
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()
        return self
    }
}
