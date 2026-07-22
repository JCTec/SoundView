import CoreGraphics
import Foundation

/// Shared timeline mapping: fixed playhead at wave-area center; content scrolls.
///
/// See `docs/MATH.md` §1.
enum ViewportMath {
    struct Range: Equatable, Sendable {
        var start: TimeInterval
        var end: TimeInterval

        var duration: TimeInterval { end - start }
    }

    /// Visible window centered on `playhead`, clamped softly to media bounds.
    static func visibleRange(
        playhead: TimeInterval,
        mediaDuration: TimeInterval,
        visibleDuration: TimeInterval
    ) -> Range {
        let half = max(visibleDuration, .leastNonzeroMagnitude) / 2
        var start = playhead - half
        var end = playhead + half

        if mediaDuration > 0 {
            if start < 0 {
                end -= start
                start = 0
            }
            if end > mediaDuration {
                start -= (end - mediaDuration)
                end = mediaDuration
                start = max(0, start)
            }
        }

        return Range(start: start, end: max(end, start))
    }

    static func timeToX(
        time: TimeInterval,
        visible: Range,
        width: CGFloat
    ) -> CGFloat {
        guard visible.duration > 0, width > 0 else { return 0 }
        let fraction = (time - visible.start) / visible.duration
        return CGFloat(fraction) * width
    }

    static func xToTime(
        x: CGFloat,
        visible: Range,
        width: CGFloat
    ) -> TimeInterval {
        guard width > 0 else { return visible.start }
        let fraction = Double(x / width)
        return visible.start + fraction * visible.duration
    }

    /// Zoom while keeping `anchorTime` under the same relative position.
    static func visibleDurationAfterZoom(
        currentVisibleDuration: TimeInterval,
        factor: Double,
        minDuration: TimeInterval = 0.05,
        maxDuration: TimeInterval = 600
    ) -> TimeInterval {
        let next = currentVisibleDuration / max(factor, .leastNonzeroMagnitude)
        return min(max(next, minDuration), maxDuration)
    }

    /// Playhead x is always the center of the wave canvas.
    static func playheadX(width: CGFloat) -> CGFloat {
        width / 2
    }

    // MARK: - Left-anchored follow (product amendment A1, docs/UI_PLAN.md)

    /// Needle anchor as a fraction of the wave width — 20% from the left.
    static let followAnchor: Double = 0.2

    /// Visible window while following: the needle pins at `anchor` once the playhead
    /// has travelled that far; before that, content holds at 0 and the needle moves.
    static func followRange(
        playhead: TimeInterval,
        visibleDuration: TimeInterval,
        anchor: Double = followAnchor
    ) -> Range {
        let lead = visibleDuration * anchor
        let start = max(0, playhead - lead)
        return Range(start: start, end: start + visibleDuration)
    }

    /// Needle x while following — travels 0→anchor from song start, then pins.
    static func followNeedleX(
        playhead: TimeInterval,
        visibleDuration: TimeInterval,
        width: CGFloat,
        anchor: Double = followAnchor
    ) -> CGFloat {
        let lead = visibleDuration * anchor
        guard lead > 0 else { return 0 }
        if playhead < lead {
            return CGFloat(playhead / visibleDuration) * width
        }
        return CGFloat(anchor) * width
    }

    /// Clamp a manually panned window start so content edges stay reachable
    /// but the wave can't be flung arbitrarily off-screen.
    static func clampedPanStart(
        _ start: TimeInterval,
        visibleDuration: TimeInterval,
        mediaDuration: TimeInterval,
        anchor: Double = followAnchor
    ) -> TimeInterval {
        let minStart = -visibleDuration * anchor
        let maxStart = max(minStart, mediaDuration - visibleDuration * (1 - anchor))
        return min(max(start, minStart), maxStart)
    }
}
