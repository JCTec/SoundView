import Foundation

/// “Nice” time-axis tick steps for waveform rulers.
///
/// See `docs/MATH.md` §3.
enum NiceScale {
    private static let candidates: [TimeInterval] = [
        0.01, 0.02, 0.05,
        0.1, 0.2, 0.5,
        1, 2, 5,
        10, 15, 30,
        60, 120, 300, 600
    ]

    /// Chooses a step so tick count stays roughly in `[minTicks, maxTicks]`.
    static func tickStep(
        visibleDuration: TimeInterval,
        minTicks: Int = 4,
        maxTicks: Int = 12
    ) -> TimeInterval {
        guard visibleDuration > 0 else { return 1 }
        let target = candidates.first { step in
            let count = visibleDuration / step
            return count >= Double(minTicks) && count <= Double(maxTicks)
        }
        return target ?? candidates.last!
    }

    /// Tick times from first multiple ≥ start through end.
    static func ticks(visibleStart: TimeInterval, visibleEnd: TimeInterval, step: TimeInterval) -> [TimeInterval] {
        guard step > 0, visibleEnd > visibleStart else { return [] }
        let first = (visibleStart / step).rounded(.up) * step
        return sequence(first: first, next: { $0 + step })
            .prefix(while: { $0 <= visibleEnd + 1e-9 })
            .map { $0 }
    }
}
