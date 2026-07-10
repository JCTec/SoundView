import SwiftUI

/// One stem lane — inline (phone) or desk (header column + wave).
struct StemLaneView: View {
    let lane: StemLaneState
    var layout: SVLaneLayout = .inline
    let onMute: () -> Void
    let onSolo: () -> Void
    let onVolume: (Float) -> Void

    @State private var muted: Bool
    @State private var soloed: Bool
    @State private var volume: Float

    init(
        lane: StemLaneState,
        layout: SVLaneLayout,
        onMute: @escaping () -> Void,
        onSolo: @escaping () -> Void,
        onVolume: @escaping (Float) -> Void
    ) {
        self.lane = lane
        self.layout = layout
        self.onMute = onMute
        self.onSolo = onSolo
        self.onVolume = onVolume
        _muted = State(initialValue: lane.isMuted)
        _soloed = State(initialValue: lane.isSoloed)
        _volume = State(initialValue: lane.volume)
    }

    var body: some View {
        Group {
            switch layout {
            case .inline:
                inlineBody
            case .desk:
                deskBody
            }
        }
        .opacity(lane.isMuted && !lane.isSoloed ? 0.35 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [lane.name, "volume \(Int(lane.volume * 100)) percent"]
        if lane.isMuted { parts.append("muted") }
        if lane.isSoloed { parts.append("soloed") }
        if lane.isLowEnergy { parts.append("low energy") }
        return parts.joined(separator: ", ")
    }

    private var inlineBody: some View {
        VStack(alignment: .leading, spacing: SVSpacing.xs) {
            HStack {
                Text(lane.name)
                    .svHeadline()
                    .foregroundStyle(LaneColorMath.color(forStemIndex: lane.index))
                if lane.isLowEnergy {
                    Text("Low energy")
                        .font(SVTypography.caption)
                        .foregroundStyle(Color.sv.textSecondary)
                }
                Spacer()
                muteSolo
            }
            wavePlaceholder
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
            .tint(LaneColorMath.color(forStemIndex: lane.index))
        }
        .padding(SVSpacing.md)
        .background(Color.sv.surface, in: RoundedRectangle(cornerRadius: SVRadius.card, style: .continuous))
    }

    private var deskBody: some View {
        HStack(spacing: 0) {
            LaneHeaderColumn(
                name: lane.name,
                color: LaneColorMath.color(forStemIndex: lane.index),
                volume: $volume,
                isMuted: $muted,
                isSoloed: $soloed,
                isLowEnergy: lane.isLowEnergy,
                onMute: {
                    muted.toggle()
                    onMute()
                },
                onSolo: {
                    soloed.toggle()
                    onSolo()
                },
                onVolume: onVolume
            )
            .frame(width: SVSpacing.deskHeaderColumn)

            wavePlaceholder
                .frame(maxWidth: .infinity)
        }
        .frame(height: SVSpacing.deskLaneHeight)
        .background(Color.sv.surface.opacity(0.6))
    }

    private var muteSolo: some View {
        SVMuteSoloButtons(
            isMuted: Binding(
                get: { muted },
                set: {
                    muted = $0
                    onMute()
                }
            ),
            isSoloed: Binding(
                get: { soloed },
                set: {
                    soloed = $0
                    onSolo()
                }
            )
        )
    }

    private var wavePlaceholder: some View {
        // Real WaveformView binds SharedViewport + PeakDecimation tiles next.
        Canvas { context, size in
            let mid = size.height / 2
            var path = Path()
            path.move(to: CGPoint(x: 0, y: mid))
            let steps = 48
            for step in 0...steps {
                let x = size.width * CGFloat(step) / CGFloat(steps)
                let y = mid + sin(CGFloat(step) * 0.45 + CGFloat(lane.index)) * (size.height * 0.35)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
                path,
                with: .color(LaneColorMath.color(forStemIndex: lane.index).opacity(0.9)),
                lineWidth: 1.5
            )
            // Fixed center playhead in wave area
            let playX = ViewportMath.playheadX(width: size.width)
            var needle = Path()
            needle.move(to: CGPoint(x: playX, y: 0))
            needle.addLine(to: CGPoint(x: playX, y: size.height))
            context.stroke(needle, with: .color(Color.sv.textPrimary.opacity(0.85)), lineWidth: 1)
        }
        .frame(height: layout == .desk ? SVSpacing.deskLaneHeight : 56)
        .background(Color.sv.canvas.opacity(0.5))
    }
}
