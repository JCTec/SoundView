import XCTest
@testable import SoundView

final class MixMatrixTests: XCTestCase {
    func testMuteSilencesWhenNoSolo() {
        let lanes = [
            MixMatrix.Lane(volume: 1, isMuted: true, isSoloed: false),
            MixMatrix.Lane(volume: 0.5, isMuted: false, isSoloed: false)
        ]
        let gains = MixMatrix.effectiveGains(lanes: lanes)
        XCTAssertEqual(gains[0], 0)
        XCTAssertEqual(gains[1], 0.5, accuracy: 0.0001)
    }

    func testSoloOverridesOthers() {
        let lanes = [
            MixMatrix.Lane(volume: 1, isMuted: false, isSoloed: true),
            MixMatrix.Lane(volume: 1, isMuted: false, isSoloed: false),
            MixMatrix.Lane(volume: 1, isMuted: true, isSoloed: true)
        ]
        let gains = MixMatrix.effectiveGains(lanes: lanes)
        XCTAssertEqual(gains[0], 1)
        XCTAssertEqual(gains[1], 0)
        XCTAssertEqual(gains[2], 1)
    }
}
