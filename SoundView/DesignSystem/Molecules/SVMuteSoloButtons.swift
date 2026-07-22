import SwiftUI

/// Per-lane Mute / Solo pair. Stateless — values in, actions out (single source of
/// truth lives in the player model). M fills Amber when on; S fills Fern (design §03).
struct SVMuteSoloButtons: View {
    let isMuted: Bool
    let isSoloed: Bool
    let onMute: () -> Void
    let onSolo: () -> Void

    var body: some View {
        HStack(spacing: SVSpacing.xs) {
            toggleButton(
                title: "M",
                isOn: isMuted,
                onColor: Color.sv.edit,
                label: "Mute",
                identifier: "mute",
                action: onMute
            )
            toggleButton(
                title: "S",
                isOn: isSoloed,
                onColor: Color.sv.accent,
                label: "Solo",
                identifier: "solo",
                action: onSolo
            )
        }
    }

    private func toggleButton(
        title: String,
        isOn: Bool,
        onColor: Color,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(SVTypography.headline.monospaced())
                .frame(width: SVSpacing.minHit, height: SVSpacing.minHit)
                .foregroundStyle(isOn ? Color.sv.canvas : Color.sv.textPrimary)
                .background(isOn ? onColor : Color.sv.surface, in: Circle())
                .animation(SVAnimation.stateFlip, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    HStack(spacing: SVSpacing.lg) {
        SVMuteSoloButtons(isMuted: false, isSoloed: false, onMute: {}, onSolo: {})
        SVMuteSoloButtons(isMuted: true, isSoloed: false, onMute: {}, onSolo: {})
        SVMuteSoloButtons(isMuted: false, isSoloed: true, onMute: {}, onSolo: {})
    }
    .padding()
    .background(Color.sv.canvas)
}
