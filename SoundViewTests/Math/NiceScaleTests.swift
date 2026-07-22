import XCTest
@testable import SoundView

final class NiceScaleTests: XCTestCase {
    func testTickCountStaysInBounds() {
        for duration in [0.5, 2, 12, 60, 300, 3_600] {
            let step = NiceScale.tickStep(visibleDuration: duration)
            let count = duration / step
            XCTAssertGreaterThanOrEqual(count, 4, "duration \(duration)")
            XCTAssertLessThanOrEqual(count, 12, "duration \(duration)")
        }
    }

    /// The regression: a 12s window with 1s ticks sits exactly on the 12-tick
    /// boundary; float wobble or a micro-pinch must not flip the step.
    func testHysteresisHoldsStepAtBoundary() {
        let initial = NiceScale.tickStep(visibleDuration: 12)
        XCTAssertEqual(initial, 1)

        // Tiny drifts around the boundary keep the current step.
        for wobble in [12.0001, 12.4, 11.6, 13.5, 15.9] {
            XCTAssertEqual(
                NiceScale.tickStep(visibleDuration: wobble, keeping: initial),
                initial,
                "wobble \(wobble) must not re-tick"
            )
        }
    }

    func testHysteresisReleasesOnRealZoom() {
        let initial = NiceScale.tickStep(visibleDuration: 12) // 1s
        // Zooming out far enough must eventually pick a bigger step…
        let zoomedOut = NiceScale.tickStep(visibleDuration: 60, keeping: initial)
        XCTAssertGreaterThan(zoomedOut, initial)
        // …and zooming in must pick a smaller one.
        let zoomedIn = NiceScale.tickStep(visibleDuration: 2, keeping: initial)
        XCTAssertLessThan(zoomedIn, initial)
    }

    func testHysteresisIgnoresNonCandidateSteps() {
        // A stale/garbage previous value never wins.
        let step = NiceScale.tickStep(visibleDuration: 12, keeping: 0.42)
        XCTAssertEqual(step, 1)
    }

    func testTicksCoverWindow() {
        let ticks = NiceScale.ticks(visibleStart: 58, visibleEnd: 70, step: 2)
        XCTAssertEqual(ticks.first, 58)
        XCTAssertEqual(ticks.last, 70)
        XCTAssertEqual(ticks.count, 7)
    }
}
