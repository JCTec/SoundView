import SwiftUI

/// Icon + one sentence + one action. No illustrations of sadness.
struct SVEmptyState: View {
    let systemImage: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: SVSpacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.sv.textSecondary)
            Text(message)
                .font(SVTypography.body)
                .foregroundStyle(Color.sv.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                SVCapsuleButton(
                    title: actionTitle,
                    systemImage: "square.and.arrow.down",
                    isFullWidth: false,
                    action: action
                )
            }
        }
        .frame(maxWidth: 320)
        .padding(SVSpacing.xl)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SVEmptyState(
        systemImage: "music.note.list",
        message: "Import a song to separate stems.",
        actionTitle: "Import",
        action: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.sv.canvas)
}
