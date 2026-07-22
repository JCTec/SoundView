import SwiftUI

/// Primary interactive capsule used across Library, Export, and transport.
struct SVCapsuleButton: View {
    enum Style: Sendable {
        case primary
        case secondary
        case destructive
        case edit
    }

    let title: String
    var systemImage: String?
    var style: Style = .primary
    var isEnabled: Bool = true
    var isFullWidth: Bool = true
    /// Applied on the button itself so UI tests resolve `A11yID` reliably.
    var accessibilityID: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SVSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(SVTypography.headline)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: SVSpacing.primaryCTAHeight)
            .padding(.horizontal, SVSpacing.lg)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityID ?? title)
    }

    private var foreground: Color {
        switch style {
        case .primary: Color.sv.canvas
        case .secondary, .edit, .destructive: Color.sv.textPrimary
        }
    }

    private var background: Color {
        switch style {
        case .primary: Color.sv.accent
        case .secondary: Color.sv.surface
        case .destructive: Color.sv.record.opacity(0.85)
        case .edit: Color.sv.edit
        }
    }
}

#Preview("Capsule buttons") {
    VStack(spacing: SVSpacing.md) {
        SVCapsuleButton(title: "Import", systemImage: "square.and.arrow.down", action: {})
        SVCapsuleButton(title: "Record", systemImage: "mic.fill", style: .secondary, action: {})
        SVCapsuleButton(title: "Separate", style: .edit, action: {})
        SVCapsuleButton(title: "Delete", style: .destructive, action: {})
    }
    .padding()
    .background(Color.sv.canvas)
}
