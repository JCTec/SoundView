import SwiftUI

/// Dynamic Type–friendly text styles for SoundView.
enum SVTypography {
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let headline = Font.system(.headline, design: .default)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    /// Monospaced digits for all timecodes — never use proportional figures for time.
    static let timecode = Font.system(.body, design: .monospaced).monospacedDigit()
    static let timecodeLarge = Font.system(.title2, design: .monospaced).monospacedDigit().weight(.medium)
}

extension View {
    func svLargeTitle() -> some View {
        font(SVTypography.largeTitle)
            .foregroundStyle(Color.sv.textPrimary)
    }

    func svHeadline() -> some View {
        font(SVTypography.headline)
            .foregroundStyle(Color.sv.textPrimary)
    }

    func svBody() -> some View {
        font(SVTypography.body)
            .foregroundStyle(Color.sv.textPrimary)
    }

    func svCaption() -> some View {
        font(SVTypography.caption)
            .foregroundStyle(Color.sv.textSecondary)
    }

    func svTimecode(large: Bool = false) -> some View {
        font(large ? SVTypography.timecodeLarge : SVTypography.timecode)
            .foregroundStyle(Color.sv.textPrimary)
    }
}
