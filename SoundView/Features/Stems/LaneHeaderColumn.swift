import SwiftUI

/// Fixed left column on desk layout — name, volume, M/S (does not scroll with wave).
struct LaneHeaderColumn: View {
    let name: String
    let color: Color
    @Binding var volume: Float
    @Binding var isMuted: Bool
    @Binding var isSoloed: Bool
    var isLowEnergy: Bool = false
    let onMute: () -> Void
    let onSolo: () -> Void
    let onVolume: (Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SVSpacing.xs) {
            Text(name)
                .font(SVTypography.headline)
                .foregroundStyle(color)
                .lineLimit(1)
            if isLowEnergy {
                Text("Low energy")
                    .font(SVTypography.caption)
                    .foregroundStyle(Color.sv.textSecondary)
            }
            Slider(
                value: Binding(
                    get: { Double(volume) },
                    set: {
                        volume = Float($0)
                        onVolume(volume)
                    }
                ),
                in: 0...1
            )
            .tint(color)
            SVMuteSoloButtons(
                isMuted: Binding(
                    get: { isMuted },
                    set: { _ in onMute() }
                ),
                isSoloed: Binding(
                    get: { isSoloed },
                    set: { _ in onSolo() }
                )
            )
        }
        .padding(.horizontal, SVSpacing.sm)
        .padding(.vertical, SVSpacing.xs)
        .frame(maxHeight: .infinity)
        .background(Color.sv.surface)
    }
}
