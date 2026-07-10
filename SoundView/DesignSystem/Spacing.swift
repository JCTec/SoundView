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
    static let deskLaneHeight: CGFloat = 88
}

enum SVRadius {
    static let capsule: CGFloat = 999
    static let card: CGFloat = 12
    static let badge: CGFloat = 8
}

enum SVLaneLayout: Equatable, Sendable {
    /// iPhone — controls sit in a horizontal header above the wave.
    case inline
    /// iPad / Mac — fixed left header column; waves share one viewport.
    case desk
}
