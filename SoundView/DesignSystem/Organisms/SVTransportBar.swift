import SwiftUI

/// Play/pause + ±15s — shared by Stem View and desk.
struct SVTransportBar: View {
    let isPlaying: Bool
    let onSkipBack: () -> Void
    let onTogglePlay: () -> Void
    let onSkipForward: () -> Void

    var body: some View {
        HStack(spacing: SVSpacing.xl) {
            Button(action: onSkipBack) {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: SVSpacing.minHit, height: SVSpacing.minHit)
            }
            .accessibilityLabel("Back 15 seconds")
            .accessibilityIdentifier(A11yID.Transport.skipBack)

            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .frame(width: SVSpacing.playControl, height: SVSpacing.playControl)
                    .foregroundStyle(Color.sv.canvas)
                    .background(Color.sv.accent, in: Circle())
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityIdentifier(A11yID.Transport.playPause)

            Button(action: onSkipForward) {
                Image(systemName: "goforward.15")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: SVSpacing.minHit, height: SVSpacing.minHit)
            }
            .accessibilityLabel("Forward 15 seconds")
            .accessibilityIdentifier(A11yID.Transport.skipForward)
        }
        .foregroundStyle(Color.sv.textPrimary)
        .buttonStyle(.plain)
    }
}

#Preview {
    SVTransportBar(isPlaying: false, onSkipBack: {}, onTogglePlay: {}, onSkipForward: {})
        .padding()
        .background(Color.sv.canvas)
}
