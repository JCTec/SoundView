import Foundation

/// User-facing stem separation modes with explicit quality guidance.
enum StemMode: String, CaseIterable, Identifiable, Sendable {
    case two = "2"
    case four = "4"
    case six = "6"
    case max = "max"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .two: "2 stems"
        case .four: "4 stems"
        case .six: "6 stems"
        case .max: "Max"
        }
    }

    var subtitle: String {
        switch self {
        case .two: "Faster · simpler mix"
        case .four: "Best quality"
        case .six: "More detail · still strong quality"
        case .max: "Everything possible · quality may drop"
        }
    }

    /// Filled bars on `SVQualityMeter` (of 5).
    var qualityBars: Int {
        switch self {
        case .two: 3
        case .four: 5
        case .six: 4
        case .max: 2
        }
    }

    var isRecommended: Bool {
        self == .four
    }

    /// Default on import / auto-separate.
    static let `default`: StemMode = .four
}
