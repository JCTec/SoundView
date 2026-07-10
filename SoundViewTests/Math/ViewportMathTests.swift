import XCTest
@testable import SoundView

final class ViewportMathTests: XCTestCase {
    func testVisibleRangeCentersPlayhead() {
        let range = ViewportMath.visibleRange(
            playhead: 50,
            mediaDuration: 100,
            visibleDuration: 20
        )
        XCTAssertEqual(range.start, 40, accuracy: 0.001)
        XCTAssertEqual(range.end, 60, accuracy: 0.001)
    }

    func testTimePixelRoundTrip() {
        let visible = ViewportMath.Range(start: 10, end: 30)
        let width: CGFloat = 300
        let time: TimeInterval = 20
        let x = ViewportMath.timeToX(time: time, visible: visible, width: width)
        let back = ViewportMath.xToTime(x: x, visible: visible, width: width)
        XCTAssertEqual(back, time, accuracy: 0.0001)
        XCTAssertEqual(x, 150, accuracy: 0.001)
    }

    func testZoomClamps() {
        let next = ViewportMath.visibleDurationAfterZoom(
            currentVisibleDuration: 10,
            factor: 1_000,
            minDuration: 0.05,
            maxDuration: 600
        )
        // 10 / 1000 = 0.01 → clamped up to minDuration
        XCTAssertEqual(next, 0.05, accuracy: 0.0001)
    }

    func testPlayheadIsCenter() {
        XCTAssertEqual(ViewportMath.playheadX(width: 400), 200)
    }
}
