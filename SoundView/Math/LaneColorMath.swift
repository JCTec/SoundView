import SwiftUI

/// Deterministic lane hues from Fern (~150°), golden-angle steps, skip red band.
///
/// See `docs/MATH.md` §7.
enum LaneColorMath {
    private static let fernHue: Double = 150
    private static let goldenAngle: Double = 137.508
    private static let lightness: Double = 0.72
    private static let saturation: Double = 0.45

    /// Stable color for stem index `n` (0-based).
    static func color(forStemIndex index: Int) -> Color {
        let hue = hueDegrees(forStemIndex: index) / 360
        return Color(hue: hue, saturation: saturation, brightness: lightness)
    }

    static func hueDegrees(forStemIndex index: Int) -> Double {
        var hue = (fernHue + Double(index) * goldenAngle)
            .truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }

        // Skip record-red band [345°, 20°].
        var guardCounter = 0
        while isInRedBand(hue), guardCounter < 12 {
            hue = (hue + goldenAngle).truncatingRemainder(dividingBy: 360)
            if hue < 0 { hue += 360 }
            guardCounter += 1
        }
        return hue
    }

    static func isInRedBand(_ hue: Double) -> Bool {
        hue >= 345 || hue <= 20
    }
}
