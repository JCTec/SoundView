import XCTest
@testable import SoundView

final class TimeFormattingTests: XCTestCase {
    func testMinutesSeconds() {
        XCTAssertEqual(TimeFormatting.timecode(seconds: 87), "1:27")
    }

    func testHours() {
        XCTAssertEqual(TimeFormatting.timecode(seconds: 3_723), "1:02:03")
    }
}
