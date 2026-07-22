import XCTest

/// Captures key UI states for design review (run on simulator only).
/// Writes PNGs under `/tmp/soundview-shots/` (copied into `docs/screenshots` after).
@MainActor
final class ScreenshotReviewTests: XCTestCase {
    private let outputDir = URL(fileURLWithPath: "/tmp/soundview-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func testCaptureCompactReviewScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-previewLibrary"]
        app.launch()

        // Library with sample packages
        XCTAssertTrue(
            app.descendants(matching: .any)[A11yMirror.Library.screen].waitForExistence(timeout: 12)
        )
        saveScreenshot(named: "03-iphone-library-preview")

        // Stem desk / stacked lanes for separated song
        let midnight = app.descendants(matching: .any)[A11yMirror.Library.row("midnight")]
        XCTAssertTrue(midnight.waitForExistence(timeout: 5), "Midnight row should exist")
        midnight.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[A11yMirror.Stem.screen].waitForExistence(timeout: 8)
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        saveScreenshot(named: "04-iphone-stem-view")

        // Back to library
        app.navigationBars.buttons.element(boundBy: 0).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))

        // Separation screen for unseparated song
        let rehearsal = app.descendants(matching: .any)[A11yMirror.Library.row("rehearsal")]
        XCTAssertTrue(rehearsal.waitForExistence(timeout: 5), "Rehearsal row should exist")
        rehearsal.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[A11yMirror.Separation.screen].waitForExistence(timeout: 8)
        )
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        saveScreenshot(named: "05-iphone-separation")

        // Back then open recorder sheet
        app.navigationBars.buttons.element(boundBy: 0).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))

        let record = app.descendants(matching: .any)[A11yMirror.Library.recordButton]
        if record.waitForExistence(timeout: 3) {
            record.tap()
        } else {
            app.buttons["Record"].firstMatch.tap()
        }
        XCTAssertTrue(
            app.descendants(matching: .any)[A11yMirror.Recorder.screen].waitForExistence(timeout: 8)
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        saveScreenshot(named: "06-iphone-recorder")
    }

    func testCaptureDeskReviewScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-previewLibrary"]
        app.launch()

        // On regular width (iPad) we should see the split desk root.
        let desk = app.descendants(matching: .any)[A11yMirror.Root.splitDesk]
        let compact = app.descendants(matching: .any)[A11yMirror.Root.compactStack]
        let appeared = desk.waitForExistence(timeout: 8) || compact.waitForExistence(timeout: 2)
        XCTAssertTrue(appeared, "Root should appear")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        saveScreenshot(named: "07-ipad-desk")

        // Select separated song if sidebar shows it (firstMatch — split may duplicate IDs).
        let midnight = app.descendants(matching: .any)[A11yMirror.Library.row("midnight")].firstMatch
        if midnight.waitForExistence(timeout: 4) {
            midnight.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
            saveScreenshot(named: "08-ipad-desk-stems")
        }
    }

    private func saveScreenshot(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = outputDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        } catch {
            XCTFail("Could not write screenshot \(name): \(error)")
        }
    }
}

/// Mirror of app `A11yID` strings (UI tests cannot import app internals reliably).
private enum A11yMirror {
    enum Root {
        static let compactStack = "root.compactStack"
        static let splitDesk = "root.splitDesk"
    }

    enum Library {
        static let screen = "library.screen"
        static let recordButton = "library.record"
        static func row(_ id: String) -> String { "library.row.\(id)" }
    }

    enum Separation {
        static let screen = "separation.screen"
    }

    enum Stem {
        static let screen = "stem.screen"
    }

    enum Recorder {
        static let screen = "recorder.screen"
    }
}
