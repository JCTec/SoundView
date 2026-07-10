import XCTest
@testable import SoundView

final class StemEnergyTests: XCTestCase {
    func testSilenceIsLowEnergy() {
        let loud = [Float](repeating: 0.5, count: 1_024)
        let quiet = [Float](repeating: 0, count: 1_024)
        let scores = StemEnergy.score(stems: [loud, quiet])
        XCTAssertFalse(scores[0].isLowEnergy)
        XCTAssertTrue(scores[1].isLowEnergy)
        XCTAssertEqual(scores[0].relative, 1, accuracy: 0.001)
    }
}
