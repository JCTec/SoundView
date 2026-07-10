import XCTest

final class SoundViewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testLibraryAppears() {
        LibraryViewRobot(app: app)
            .waitForScreen()
    }

    func testRecordOpensRecorder() {
        LibraryViewRobot(app: app)
            .waitForScreen()
            .tapRecord()
        RecorderViewRobot(app: app)
            .waitForScreen()
    }
}
