import XCTest
@testable import SoundView

final class LaneColorMathTests: XCTestCase {
    func testDeterministicHues() {
        let a = LaneColorMath.hueDegrees(forStemIndex: 3)
        let b = LaneColorMath.hueDegrees(forStemIndex: 3)
        XCTAssertEqual(a, b, accuracy: 0.0001)
    }

    func testSkipsRedBand() {
        for index in 0..<24 {
            let hue = LaneColorMath.hueDegrees(forStemIndex: index)
            XCTAssertFalse(LaneColorMath.isInRedBand(hue), "index \(index) hue \(hue)")
        }
    }
}
