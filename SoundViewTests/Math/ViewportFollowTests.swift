import XCTest
@testable import SoundView

/// Amendment A1 — left-anchored follow playhead (docs/UI_PLAN.md).
final class ViewportFollowTests: XCTestCase {
    private let window: TimeInterval = 12 // default zoom
    private var lead: TimeInterval { window * ViewportMath.followAnchor }

    // MARK: - Window

    func testWindowHoldsAtZeroBeforeAnchor() {
        let range = ViewportMath.followRange(playhead: 1, visibleDuration: window)
        XCTAssertEqual(range.start, 0, accuracy: 0.0001)
        XCTAssertEqual(range.end, window, accuracy: 0.0001)
    }

    func testWindowScrollsOncePlayheadPassesAnchor() {
        let playhead: TimeInterval = 60
        let range = ViewportMath.followRange(playhead: playhead, visibleDuration: window)
        XCTAssertEqual(range.start, playhead - lead, accuracy: 0.0001)
        XCTAssertEqual(range.duration, window, accuracy: 0.0001)
    }

    // MARK: - Needle

    func testNeedleTravelsFromLeftAtSongStart() {
        let width: CGFloat = 1_000
        XCTAssertEqual(
            ViewportMath.followNeedleX(playhead: 0, visibleDuration: window, width: width),
            0, accuracy: 0.01
        )
        // Halfway to the anchor lead → halfway to the anchor x.
        let x = ViewportMath.followNeedleX(playhead: lead / 2, visibleDuration: window, width: width)
        XCTAssertEqual(x, width * ViewportMath.followAnchor / 2, accuracy: 0.5)
    }

    func testNeedlePinsAtAnchorAfterLead() {
        let width: CGFloat = 1_000
        let anchorX = width * ViewportMath.followAnchor
        for playhead in [lead, 30, 120, 500] {
            let x = ViewportMath.followNeedleX(playhead: playhead, visibleDuration: window, width: width)
            XCTAssertEqual(x, anchorX, accuracy: 0.01, "needle must pin at anchor for playhead \(playhead)")
        }
    }

    func testNeedleMatchesWindowMapping() {
        // Where the needle pins, timeToX(playhead) inside followRange must agree.
        let playhead: TimeInterval = 90
        let width: CGFloat = 800
        let range = ViewportMath.followRange(playhead: playhead, visibleDuration: window)
        let mapped = ViewportMath.timeToX(time: playhead, visible: range, width: width)
        let pinned = ViewportMath.followNeedleX(playhead: playhead, visibleDuration: window, width: width)
        XCTAssertEqual(mapped, pinned, accuracy: 0.01)
    }

    // MARK: - Pan clamping

    func testPanClampAllowsSmallLeadIn() {
        let clamped = ViewportMath.clampedPanStart(
            -100, visibleDuration: window, mediaDuration: 300
        )
        XCTAssertEqual(clamped, -window * ViewportMath.followAnchor, accuracy: 0.0001)
    }

    func testPanClampKeepsEndReachable() {
        let clamped = ViewportMath.clampedPanStart(
            1_000, visibleDuration: window, mediaDuration: 300
        )
        XCTAssertEqual(clamped, 300 - window * (1 - ViewportMath.followAnchor), accuracy: 0.0001)
    }

    func testPanClampPassesThroughMidRange() {
        let clamped = ViewportMath.clampedPanStart(
            100, visibleDuration: window, mediaDuration: 300
        )
        XCTAssertEqual(clamped, 100, accuracy: 0.0001)
    }
}
