import XCTest
@testable import SoundView

final class PeakTierMathTests: XCTestCase {
    func testRequiredBucketsGrowsWithZoom() {
        // 300s song, 900pt wave, 3pt bars → 300 bars on screen.
        let zoomedOut = PeakTierMath.requiredBuckets(
            visibleDuration: 300, mediaDuration: 300, width: 900, barStep: 3
        )
        let zoomedIn = PeakTierMath.requiredBuckets(
            visibleDuration: 12, mediaDuration: 300, width: 900, barStep: 3
        )
        XCTAssertEqual(zoomedOut, 300)
        XCTAssertEqual(zoomedIn, 7_500)
        XCTAssertGreaterThan(zoomedIn, zoomedOut)
    }

    func testBestTierPicksSmallestSufficient() {
        let tiers = PeakTierMath.standardTiers
        XCTAssertEqual(PeakTierMath.bestTier(available: tiers, required: 300), 2_048)
        XCTAssertEqual(PeakTierMath.bestTier(available: tiers, required: 200), 256)
        XCTAssertEqual(PeakTierMath.bestTier(available: tiers, required: 7_500), 16_384)
    }

    func testBestTierFallsBackToFinest() {
        XCTAssertEqual(PeakTierMath.bestTier(available: PeakTierMath.standardTiers, required: 100_000), 16_384)
        XCTAssertNil(PeakTierMath.bestTier(available: [], required: 10))
    }

    func testDegenerateInputsAreSafe() {
        XCTAssertEqual(
            PeakTierMath.requiredBuckets(visibleDuration: 0, mediaDuration: 300, width: 900, barStep: 3),
            1
        )
        XCTAssertEqual(
            PeakTierMath.requiredBuckets(visibleDuration: 12, mediaDuration: 0, width: 900, barStep: 3),
            1
        )
    }

    func testWaveformTiersSelectionRoundTrip() {
        let coarse = [PeakDecimation.Peak(min: -0.5, max: 0.5)]
        let fine = Array(repeating: PeakDecimation.Peak(min: -0.9, max: 0.9), count: 2_048)
        let tiers = WaveformTiers(tiers: [256: coarse, 2_048: fine], duration: 300)
        XCTAssertEqual(tiers.peaks(required: 10).count, coarse.count)
        XCTAssertEqual(tiers.peaks(required: 1_000).count, fine.count)
    }

    func testDurationScaledTiersCoverMaxZoom() {
        // 5-minute song: finest tier must out-resolve the deepest zoom
        // (2s window across a 2000pt Mac canvas = ~333 columns/second).
        let duration: TimeInterval = 300
        let finest = PeakDecimation.bucketCount(
            forDuration: duration,
            peaksPerSecond: WaveformTiers.peaksPerSecondTiers.max() ?? 0
        )
        let required = PeakTierMath.requiredBuckets(
            visibleDuration: 2, mediaDuration: duration, width: 2_000, barStep: 3
        )
        XCTAssertGreaterThanOrEqual(finest, required)
    }
}
