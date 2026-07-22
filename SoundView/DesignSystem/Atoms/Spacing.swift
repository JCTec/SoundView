import CoreGraphics

/// Spacing, radii, and control metrics.
enum SVSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let minHit: CGFloat = 44
    static let primaryCTAHeight: CGFloat = 54
    static let playControl: CGFloat = 62
    static let deskHeaderColumn: CGFloat = 148
    static let laneHeight: CGFloat = 72
    /// Desk lanes flex between these; they fill available height (amendment: no dead space).
    static let deskLaneMinHeight: CGFloat = 88
    static let deskLaneMaxHeight: CGFloat = 160
    static let rulerHeight: CGFloat = 22
}

enum SVRadius {
    static let capsule: CGFloat = 999
    static let card: CGFloat = 12
    static let badge: CGFloat = 8
}

/// Wave drawing metrics — one place, every canvas.
enum SVWaveMetrics {
    /// Horizontal step per peak bar (bar + gap).
    static let barStep: CGFloat = 3
    static let barWidth: CGFloat = 2
    static let needleWidth: CGFloat = 2
    /// Vertical fill of a lane the wave may occupy.
    static let verticalFill: CGFloat = 0.88
    /// Unplayed (right-of-needle) wave alpha.
    static let unplayedAlpha: Double = 0.28
    /// Muted lane alpha (design §03).
    static let mutedAlpha: Double = 0.35
    /// Non-soloed lanes gray out to this alpha when any solo is active.
    static let backgroundedAlpha: Double = 0.45
}

enum SVLaneLayout: Equatable, Sendable {
    /// iPhone — controls sit in a horizontal header above the wave.
    case inline
    /// iPad / Mac — fixed left header column; waves share one viewport.
    case desk
}
