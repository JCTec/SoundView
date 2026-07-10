import CoreMedia
import Foundation

/// Handle positions → sample-accurate `CMTimeRange`.
///
/// See `docs/MATH.md` §8.
enum TrimMath {
    struct SecondsRange: Equatable, Sendable {
        var start: TimeInterval
        var end: TimeInterval

        var duration: TimeInterval { end - start }
    }

    /// Orders and clamps a selection into \([0, mediaDuration]\).
    static func normalized(
        start: TimeInterval,
        end: TimeInterval,
        mediaDuration: TimeInterval,
        minimumDuration: TimeInterval = 0.001
    ) -> SecondsRange {
        let lo = min(start, end)
        let hi = max(start, end)
        let clampedStart = min(max(lo, 0), max(mediaDuration, 0))
        var clampedEnd = min(max(hi, 0), max(mediaDuration, 0))
        if clampedEnd - clampedStart < minimumDuration {
            clampedEnd = min(mediaDuration, clampedStart + minimumDuration)
        }
        return SecondsRange(start: clampedStart, end: max(clampedEnd, clampedStart))
    }

    static func cmTimeRange(
        _ range: SecondsRange,
        preferredTimescale: CMTimeScale = 44_100
    ) -> CMTimeRange {
        let start = CMTime(seconds: range.start, preferredTimescale: preferredTimescale)
        let duration = CMTime(seconds: range.duration, preferredTimescale: preferredTimescale)
        return CMTimeRange(start: start, duration: duration)
    }
}
