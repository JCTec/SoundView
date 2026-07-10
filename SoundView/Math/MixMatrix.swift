import Foundation

/// Resolves effective playback gains from mute / solo / volume.
///
/// Solo overrides: if any lane is soloed, only soloed lanes play.
/// See `docs/MATH.md` §6.
enum MixMatrix {
    struct Lane: Equatable, Sendable {
        var volume: Float
        var isMuted: Bool
        var isSoloed: Bool
    }

    /// Returns linear gains (0…1+) per lane after mute/solo rules.
    static func effectiveGains(lanes: [Lane]) -> [Float] {
        let anySolo = lanes.contains(where: \.isSoloed)
        return lanes.map { lane in
            if anySolo {
                return lane.isSoloed ? clamped(lane.volume) : 0
            }
            if lane.isMuted { return 0 }
            return clamped(lane.volume)
        }
    }

    private static func clamped(_ volume: Float) -> Float {
        min(max(volume, 0), 2)
    }
}
