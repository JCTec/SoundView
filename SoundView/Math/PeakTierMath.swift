import CoreGraphics
import Foundation

/// Chooses which peak-decimation tier to draw at the current zoom.
///
/// A tier is "enough" when it provides at least one peak bucket per drawn bar
/// across the visible window; we pick the coarsest tier that still satisfies that,
/// so deep zoom-out never touches the 16k tier.
enum PeakTierMath {
    /// Standard tiers per stem: coarse → fine.
    static let standardTiers = [256, 2_048, 16_384]

    /// Buckets needed to draw `width` points of the visible window at `barStep` pt/bar.
    static func requiredBuckets(
        visibleDuration: TimeInterval,
        mediaDuration: TimeInterval,
        width: CGFloat,
        barStep: CGFloat
    ) -> Int {
        guard visibleDuration > 0, mediaDuration > 0, width > 0, barStep > 0 else { return 1 }
        let barsOnScreen = Double(width / barStep)
        let bucketsAcrossMedia = barsOnScreen * (mediaDuration / visibleDuration)
        return max(1, Int(bucketsAcrossMedia.rounded(.up)))
    }

    /// Smallest available tier that covers `required`; falls back to the finest tier.
    static func bestTier(available: [Int], required: Int) -> Int? {
        let sorted = available.sorted()
        return sorted.first { $0 >= required } ?? sorted.last
    }
}
