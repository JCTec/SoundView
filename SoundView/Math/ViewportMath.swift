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
}
