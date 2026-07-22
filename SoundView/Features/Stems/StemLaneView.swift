import SwiftUI

/// One stem lane — inline (phone card) or desk (header column + wave).
/// Stateless: lane values + viewport in, intents out. Design §03 states:
/// muted dims to 35%; when any lane is soloed, non-soloed lanes gray out.
struct StemLaneView: View {
    let lane: StemLaneState
    let layout: SVLaneLayout
    let visible: ViewportMath.Range
    let playhead: TimeInterval
    /// True when any lane in the desk is soloed (grays out the others).
    let anySolo: Bool
    /// When set, the wave surface gains the shared timeline gestures
    /// (drag pans all lanes, pinch zooms, tap seeks). Controls stay untouched.
    var gestureModel: StemPlayerModel?
    let onMute: () -> Void
    let onSolo: () -> Void
    let onVolume: (Float) -> Void
    /// Long-press "Export this stem". Optional so previews/desk can omit it.
    var onExport: (() -> Void)?

    private var color: Color { LaneColorMath.color(forStemIndex: lane.index) }

    private var isBackgrounded: Bool { anySolo && !lane.isSoloed }

    private var laneAlpha: Double {
        if lane.isMuted && !lane.isSoloed { return SVWaveMetrics.mutedAlpha }
        if isBackgrounded { return SVWaveMetrics.backgroundedAlpha }
        return 1
    }

    var body: some View {
        Group {
            switch layout {
            case .inline: inlineBody
            case .desk: deskBody
            }
        }
        .opacity(laneAlpha)
        .animation(SVAnimation.stateFlip, value: laneAlpha)
        .contextMenu { laneMenu }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var laneMenu: some View {
        if let onExport {
            Button {
                onExport()
            } label: {
                Label("Export this stem", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier(A11yID.Stem.laneExport(lane.id))
        }
    }

    // MARK: - Layouts

    private var inlineBody: some View {
        VStack(alignment: .leading, spacing: SVSpacing.xs) {
            HStack {
                Text(lane.name)
                    .font(SVTypography.headline)
                    .foregroundStyle(color)
                if lane.isLowEnergy {
                    Text("Low energy")
                        .font(SVTypography.caption)
                        .foregroundStyle(Color.sv.textSecondary)
                }
                Spacer()
                SVMuteSoloButtons(
                    isMuted: lane.isMuted,
                    isSoloed: lane.isSoloed,
                    onMute: onMute,
                    onSolo: onSolo
                )
            }
            wave
                .frame(height: SVSpacing.laneHeight)
            SVVolumeSlider(
                volume: Binding(get: { lane.volume }, set: { onVolume($0) }),
                tint: color
            )
        }
        .padding(SVSpacing.md)
        .background(soloTintedSurface, in: RoundedRectangle(cornerRadius: SVRadius.card, style: .continuous))
    }

    private var deskBody: some View {
        HStack(spacing: 0) {
            LaneHeaderColumn(
                lane: lane,
                color: color,
                onMute: onMute,
                onSolo: onSolo,
                onVolume: onVolume
            )
            .frame(width: SVSpacing.deskHeaderColumn)

            wave
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(soloTintedSurface)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var wave: some View {
        ZStack {
            if lane.waveform.isEmpty {
                SVLoadingWave(color: color)
                    .transition(.opacity)
            } else {
                loadedCanvas
                    .transition(.opacity)
            }
        }
        .animation(SVAnimation.chrome, value: lane.waveform.isEmpty)
    }

    @ViewBuilder
    private var loadedCanvas: some View {
        let canvas = SVWaveformCanvas(
            waveform: lane.waveform,
            visible: visible,
            playhead: playhead,
            color: color
        )
        if let gestureModel {
            canvas.waveTimelineGestures(gestureModel)
        } else {
            canvas
        }
    }

    /// Soloed lane's background tints toward its color (design §03 "lane bg tints").
    private var soloTintedSurface: Color {
        lane.isSoloed ? color.opacity(0.1) : Color.sv.surface.opacity(layout == .desk ? 0.6 : 1)
    }

    private var accessibilitySummary: String {
        var parts = [lane.name, "volume \(Int(lane.volume * 100)) percent"]
        if lane.isMuted { parts.append("muted") }
        if lane.isSoloed { parts.append("soloed") }
        if lane.isLowEnergy { parts.append("low energy") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(spacing: SVSpacing.md) {
        StemLaneView(
            lane: StemLaneState(
                id: "vocals", name: "Vocals", index: 0, volume: 0.8,
                isMuted: false, isSoloed: false, isLowEnergy: false, waveform: .empty
            ),
            layout: .inline,
            visible: .init(start: 0, end: 12),
            playhead: 4,
            anySolo: false,
            onMute: {}, onSolo: {}, onVolume: { _ in }
        )
        StemLaneView(
            lane: StemLaneState(
                id: "drums", name: "Drums", index: 1, volume: 1,
                isMuted: true, isSoloed: false, isLowEnergy: false, waveform: .empty
            ),
            layout: .desk,
            visible: .init(start: 0, end: 12),
            playhead: 4,
            anySolo: false,
            onMute: {}, onSolo: {}, onVolume: { _ in }
        )
        .frame(height: 100)
    }
    .padding()
    .background(Color.sv.canvas)
}
