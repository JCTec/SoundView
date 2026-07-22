import SwiftUI

/// Appears when the user scrolls away from follow mode; tapping re-engages it.
struct SVReturnToPlayheadChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SVSpacing.xs) {
                Image(systemName: "arrow.backward.to.line")
                    .font(.caption.weight(.semibold))
                Text("Playhead")
                    .font(SVTypography.caption.weight(.medium))
            }
            .foregroundStyle(Color.sv.canvas)
            .padding(.horizontal, SVSpacing.md)
            .padding(.vertical, SVSpacing.sm)
            .background(Color.sv.accent, in: Capsule())
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return to playhead")
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

#Preview {
    SVReturnToPlayheadChip {}
        .padding()
        .background(Color.sv.canvas)
}
