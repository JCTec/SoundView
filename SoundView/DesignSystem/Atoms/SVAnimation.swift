import SwiftUI

/// Motion tokens — durations and springs. Features never hardcode animation values.
enum SVAnimation {
    /// Quick state flips: mute dim, solo tint, selection.
    static let stateFlip = Animation.easeOut(duration: 0.18)
    /// Panel / chrome transitions.
    static let chrome = Animation.easeInOut(duration: 0.25)
    /// Bouncy affordances: chips, knobs.
    static let spring = Animation.spring(duration: 0.35, bounce: 0.2)
    /// Zoom settle after pinch ends.
    static let zoomSettle = Animation.easeOut(duration: 0.2)
}
