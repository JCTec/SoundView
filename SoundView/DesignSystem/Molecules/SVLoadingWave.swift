import SwiftUI

/// Placeholder while a lane's peaks decode: ghost bars in the lane color with a
/// soft highlight sweeping through — clearly "loading", never "broken".
/// Cross-fades into `SVWaveformCanvas` when the real pyramid lands.
struct SVLoadingWave: View {
    var color: Color = Color.sv.accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 2.4) / 2.4
                let sweepX = CGFloat(phase) * (size.width * 1.4) - size.width * 0.2
                let mid = size.height / 2
                let step = SVWaveMetrics.barStep
                var x: CGFloat = 0
                var index = 0
                while x < size.width {
                    // Deterministic ghost heights — calm, wave-like, no flicker.
                    let unit = abs(sin(Double(index) * 0.35)) * 0.5 + 0.15
                    let barHeight = max(2, CGFloat(unit) * size.height * 0.5)
                    let distance = abs(x - sweepX)
                    let highlight = max(0, 1 - distance / 120)
                    let alpha = 0.14 + 0.22 * Double(highlight)
                    let rect = CGRect(
                        x: x, y: mid - barHeight / 2,
                        width: SVWaveMetrics.barWidth, height: barHeight
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: SVWaveMetrics.barWidth / 2),
                        with: .color(color.opacity(alpha))
                    )
                    x += step
                    index += 1
                }
            }
        }
        .accessibilityLabel("Loading waveform")
    }
}

#Preview {
    VStack(spacing: SVSpacing.md) {
        SVLoadingWave(color: LaneColorMath.color(forStemIndex: 0))
            .frame(height: 72)
        SVLoadingWave(color: LaneColorMath.color(forStemIndex: 1))
            .frame(height: 72)
    }
    .padding()
    .background(Color.sv.canvas)
}
