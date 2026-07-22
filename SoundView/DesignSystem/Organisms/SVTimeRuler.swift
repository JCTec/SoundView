import SwiftUI

/// Time ruler above the lane stack — nice tick steps per zoom (`NiceScale`),
/// labels in monospaced digits, re-ticks live as the window scrolls or zooms.
struct SVTimeRuler: View {
    let visible: ViewportMath.Range

    /// Last step drawn — feeds NiceScale's hysteresis so the ruler never flaps
    /// between two steps when the window sits on a tick-count boundary.
    @State private var lastStep: TimeInterval = 0

    var body: some View {
        let step = NiceScale.tickStep(
            visibleDuration: visible.duration,
            keeping: lastStep > 0 ? lastStep : nil
        )
        return Canvas { context, size in
            guard visible.duration > 0 else { return }
            let ticks = NiceScale.ticks(visibleStart: max(0, visible.start), visibleEnd: visible.end, step: step)

            for tick in ticks {
                let x = ViewportMath.timeToX(time: tick, visible: visible, width: size.width)
                guard x >= -40, x <= size.width + 40 else { continue }

                var line = Path()
                line.move(to: CGPoint(x: x, y: size.height - 5))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(Color.sv.textSecondary.opacity(0.6)), lineWidth: 1)

                let label = Text(TimeFormatting.timecode(seconds: tick))
                    .font(SVTypography.caption.monospacedDigit())
                    .foregroundColor(Color.sv.textSecondary.opacity(0.8))
                context.draw(label, at: CGPoint(x: x, y: size.height - 13), anchor: .center)
            }
        }
        .frame(height: SVSpacing.rulerHeight)
        .accessibilityHidden(true)
        .onChange(of: step, initial: true) { _, newValue in
            lastStep = newValue
        }
    }
}

#Preview {
    VStack(spacing: SVSpacing.md) {
        SVTimeRuler(visible: .init(start: 58, end: 70))
        SVTimeRuler(visible: .init(start: 0, end: 300))
    }
    .padding()
    .background(Color.sv.canvas)
}
