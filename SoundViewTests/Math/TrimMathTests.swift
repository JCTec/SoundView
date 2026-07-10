import XCTest
@testable import SoundView

final class TrimMathTests: XCTestCase {
    func testSwapsInvertedHandles() {
        let range = TrimMath.normalized(start: 10, end: 2, mediaDuration: 20)
        XCTAssertEqual(range.start, 2, accuracy: 0.0001)
        XCTAssertEqual(range.end, 10, accuracy: 0.0001)
    }

    func testClampsToMedia() {
        let range = TrimMath.normalized(start: -5, end: 100, mediaDuration: 50)
        XCTAssertEqual(range.start, 0, accuracy: 0.0001)
        XCTAssertEqual(range.end, 50, accuracy: 0.0001)
    }
}
