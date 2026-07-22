import Foundation

/// Wall-clock anchor for sample-locked playback time.
///
/// The mixer re-anchors on every play / pause / seek; between anchors the UI
/// extrapolates per rendered frame — continuous 60 fps motion, no polling timer.
///
/// See `docs/MATH.md` §8.
struct PlaybackClock: Equatable, Sendable {
    /// Media time at the anchor moment.
    var anchorMediaTime: TimeInterval
    /// Wall date of the anchor; `nil` while paused.
    var anchorDate: Date?
    /// Media length, used to clamp extrapolation.
    var mediaDuration: TimeInterval

    static let zero = PlaybackClock(anchorMediaTime: 0, anchorDate: nil, mediaDuration: 0)

    var isPlaying: Bool { anchorDate != nil }

    /// Extrapolated media time at `date`, clamped to `0...mediaDuration`.
    func time(at date: Date) -> TimeInterval {
        let raw: TimeInterval
        if let anchorDate {
            raw = anchorMediaTime + date.timeIntervalSince(anchorDate)
        } else {
            raw = anchorMediaTime
        }
        return min(max(0, raw), max(0, mediaDuration))
    }

    /// True once extrapolated time has reached the end of the media.
    func hasEnded(at date: Date) -> Bool {
        mediaDuration > 0 && time(at: date) >= mediaDuration
    }

    // MARK: - Transitions

    static func paused(at mediaTime: TimeInterval, duration: TimeInterval) -> PlaybackClock {
        PlaybackClock(
            anchorMediaTime: min(max(0, mediaTime), max(0, duration)),
            anchorDate: nil,
            mediaDuration: duration
        )
    }

    static func playing(from mediaTime: TimeInterval, duration: TimeInterval, at date: Date = Date()) -> PlaybackClock {
        PlaybackClock(
            anchorMediaTime: min(max(0, mediaTime), max(0, duration)),
            anchorDate: date,
            mediaDuration: duration
        )
    }

    /// Same transport state, new position — used by seek.
    func seeking(to mediaTime: TimeInterval, at date: Date = Date()) -> PlaybackClock {
        if isPlaying {
            return .playing(from: mediaTime, duration: mediaDuration, at: date)
        }
        return .paused(at: mediaTime, duration: mediaDuration)
    }
}
