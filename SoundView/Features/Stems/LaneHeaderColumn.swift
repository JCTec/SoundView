import SwiftUI

/// Fixed left column on desk layout — name, volume, M/S. Stateless: reads lane
/// values, forwards intents to the player model (never scrolls with the wave).
struct LaneHeaderColumn: View {
    let lane: StemLaneState
    let color: Color
    let onMute: () -> Void
    let onSolo: () -> Void
    let onVolume: (Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SVSpacing.xs) {
            HStack(spacing: SVSpacing.xs) {
                Text(lane.name)
                    .font(SVTypography.headline)
                    .foregroundStyle(color)
                    .lineLimit(1)
                if lane.isSoloed {
                    Text("SOLO")
                        .font(SVTypography.caption.weight(.bold))
                        .foregroundStyle(Color.sv.canvas)
                        .padding(.horizontal, SVSpacing.xs)
                        .padding(.vertical, 1)
                        .background(Color.sv.edit, in: RoundedRectangle(cornerRadius: SVRadius.badge))
                }
            }
            if lane.isLowEnergy {
                Text("Low energy")
                    .font(SVTypography.caption)
                    .foregroundStyle(Color.sv.textSecondary)
            }
            SVVolumeSlider(
                volume: Binding(
                    get: { lane.volume },
                    set: { onVolume($0) }
                ),
                tint: color
            )
            SVMuteSoloButtons(
                isMuted: lane.isMuted,
                isSoloed: lane.isSoloed,
                onMute: onMute,
                onSolo: onSolo
            )
        }
        .padding(.horizontal, SVSpacing.sm)
        .padding(.vertical, SVSpacing.xs)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color.sv.surface)
    }
}

#Preview {
    LaneHeaderColumn(
        lane: StemLaneState(
            id: "vocals", name: "Vocals", index: 0,
            volume: 0.8, isMuted: false, isSoloed: true,
            isLowEnergy: false, waveform: .empty
        ),
        color: LaneColorMath.color(forStemIndex: 0),
        onMute: {}, onSolo: {}, onVolume: { _ in }
    )
    .frame(width: SVSpacing.deskHeaderColumn, height: 120)
    .background(Color.sv.canvas)
}
