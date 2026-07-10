import SwiftUI

/// Per-lane Mute / Solo pair (multi-solo allowed).
struct SVMuteSoloButtons: View {
    @Binding var isMuted: Bool
    @Binding var isSoloed: Bool

    var body: some View {
        HStack(spacing: SVSpacing.xs) {
            toggleButton(
                title: "M",
                isOn: isMuted,
                onColor: Color.sv.edit,
                identifier: "mute"
            ) {
                isMuted.toggle()
            }
            toggleButton(
                title: "S",
                isOn: isSoloed,
                onColor: Color.sv.accent,
                identifier: "solo"
            ) {
                isSoloed.toggle()
            }
        }
    }

    private func toggleButton(
        title: String,
        isOn: Bool,
        onColor: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(SVTypography.headline.monospaced())
                .frame(width: SVSpacing.minHit, height: SVSpacing.minHit)
                .foregroundStyle(isOn ? Color.sv.canvas : Color.sv.textPrimary)
                .background(isOn ? onColor : Color.sv.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "M" ? "Mute" : "Solo")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    struct Host: View {
        @State private var muted = false
        @State private var soloed = true
        var body: some View {
            SVMuteSoloButtons(isMuted: $muted, isSoloed: $soloed)
                .padding()
                .background(Color.sv.canvas)
        }
    }
    return Host()
}
