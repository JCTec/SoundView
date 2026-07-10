import XCTest
@testable import SoundView

final class OverlapAddTests: XCTestCase {
    func testHannWindowIsZeroAtEndsAndPositiveInMiddle() {
        let window = OverlapAdd.hannWindow(length: 8)
        XCTAssertEqual(window.count, 8)
        XCTAssertEqual(window.first!, 0, accuracy: 0.001)
        XCTAssertGreaterThan(window[window.count / 2], 0.9)
    }

    func testNormalizeDividesByWeights() {
        let normalized = OverlapAdd.normalize(output: [2, 4], weights: [2, 2])
        XCTAssertEqual(normalized[0], 1, accuracy: 0.0001)
        XCTAssertEqual(normalized[1], 2, accuracy: 0.0001)
    }
}
