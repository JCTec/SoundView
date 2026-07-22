import SwiftUI

/// Viewport-driven peak wave for one lane. Draws only the visible time range from
/// the best-matching peak tier; played audio (left of the needle) renders in the
/// lane color, unplayed to the right in low alpha. The needle itself is drawn once,
/// across all lanes, by the desk — not here.
struct SVWaveformCanvas: View {
    let waveform: WaveformTiers
    let visible: ViewportMath.Range
    /// Current playhead time, for the played/unplayed split.
    let playhead: TimeInterval
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard !waveform.isEmpty, waveform.duration > 0, visible.duration > 0 else {
                drawPlaceholder(context: context, size: size)
                return
            }

            let required = PeakTierMath.requiredBuckets(
                visibleDuration: visible.duration,
                mediaDuration: waveform.duration,
                width: size.width,
                barStep: SVWaveMetrics.barStep
            )
            let peaks = waveform.peaks(required: required)
            guard !peaks.isEmpty else { return }

            // One bar per screen column, columns anchored to a global time grid —
            // uniform spacing (no aliasing gaps) and bars keep identity while the
            // wave scrolls under the fixed needle instead of shimmering.
            let bucketDuration = waveform.duration / Double(peaks.count)
            let columnDuration = visible.duration * Double(SVWaveMetrics.barStep / max(size.width, 1))
            guard bucketDuration > 0, columnDuration > 0 else { return }

            let mid = size.height / 2
            let amplitude = size.height * SVWaveMetrics.verticalFill / 2
            let firstColumn = Int((visible.start / columnDuration).rounded(.down))
            let lastColumn = Int((visible.end / columnDuration).rounded(.up))
            guard firstColumn <= lastColumn else { return }

            for column in firstColumn...lastColumn {
                let timeStart = Double(column) * columnDuration
                let timeEnd = timeStart + columnDuration
                guard timeEnd > 0, timeStart < waveform.duration else { continue }

                // Aggregate every bucket this column covers (min/max preserved —
                // transients never vanish when zoomed out).
                let bucketStart = max(0, Int(timeStart / bucketDuration))
                let bucketEnd = min(peaks.count - 1, Int(timeEnd / bucketDuration))
                guard bucketStart <= bucketEnd else { continue }
                var low: Float = 0
                var high: Float = 0
                for bucket in bucketStart...bucketEnd {
                    low = min(low, peaks[bucket].min)
                    high = max(high, peaks[bucket].max)
                }

                let x = ViewportMath.timeToX(time: timeStart, visible: visible, width: size.width)
                let top = mid - CGFloat(min(1, abs(high))) * amplitude
                let bottom = mid + CGFloat(min(1, abs(low))) * amplitude
                let rect = CGRect(
                    x: x,
                    y: top,
                    width: SVWaveMetrics.barWidth,
                    height: max(1.5, bottom - top)
                )
                let isPlayed = timeStart <= playhead
                context.fill(
                    Path(roundedRect: rect, cornerRadius: SVWaveMetrics.barWidth / 2),
                    with: .color(isPlayed ? color : color.opacity(SVWaveMetrics.unplayedAlpha))
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// Soft center line until peaks load.
    private func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(path, with: .color(color.opacity(0.25)), lineWidth: 1)
    }
}

#Preview {
    let peaks = (0..<2_048).map { index -> PeakDecimation.Peak in
        let value = Float(abs(sin(Double(index) * 0.05)) * 0.8 + 0.1)
        return PeakDecimation.Peak(min: -value, max: value)
    }
    let tiers = WaveformTiers(tiers: [2_048: peaks], duration: 300)
    return SVWaveformCanvas(
        waveform: tiers,
        visible: .init(start: 60, end: 72),
        playhead: 64,
        color: LaneColorMath.color(forStemIndex: 0)
    )
    .frame(height: 96)
    .padding()
    .background(Color.sv.canvas)
}
