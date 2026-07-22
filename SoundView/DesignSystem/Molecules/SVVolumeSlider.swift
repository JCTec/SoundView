import SwiftUI

/// Lane volume — capsule track, fat 24pt knob inside a 44pt hit area, lane-tinted.
/// Replaces stock `Slider` (design: "fat volume knobs", no stock controls).
struct SVVolumeSlider: View {
    @Binding var volume: Float
    var tint: Color = .sv.accent

    private let knobSize: CGFloat = 24
    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let usable = max(1, width - knobSize)
            let x = CGFloat(min(max(volume, 0), 1)) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.sv.textPrimary.opacity(0.15))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(tint)
                    .frame(width: x + knobSize / 2, height: trackHeight)
                Circle()
                    .fill(Color.sv.textPrimary)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = (value.location.x - knobSize / 2) / usable
                        volume = Float(min(max(fraction, 0), 1))
                    }
            )
        }
        .frame(height: SVSpacing.minHit)
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(volume * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step: Float = 0.05
            volume = min(max(volume + (direction == .increment ? step : -step), 0), 1)
        }
    }
}

#Preview {
    struct Host: View {
        @State private var volume: Float = 0.7
        var body: some View {
            SVVolumeSlider(volume: $volume, tint: LaneColorMath.color(forStemIndex: 1))
                .frame(width: 160)
                .padding()
                .background(Color.sv.canvas)
        }
    }
    return Host()
}
