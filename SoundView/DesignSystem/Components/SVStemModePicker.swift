import SwiftUI

/// Stem count selection with explicit quality guidance.
/// 4 and 6 are high quality; Max shows possibility at lower isolation quality.
struct SVStemModePicker: View {
    @Binding var selection: StemMode

    var body: some View {
        VStack(alignment: .leading, spacing: SVSpacing.md) {
            Text("How many stems?")
                .svHeadline()

            Text(
                "4 or 6 stems give the cleanest separation. "
                    + "More stems can isolate extra parts, but bleed and artifacts increase."
            )
            .font(SVTypography.caption)
            .foregroundStyle(Color.sv.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: SVSpacing.sm) {
                ForEach(StemMode.allCases) { mode in
                    modeRow(mode)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.ModePicker.picker)
    }

    private func modeRow(_ mode: StemMode) -> some View {
        Button {
            selection = mode
        } label: {
            HStack(spacing: SVSpacing.md) {
                Image(systemName: selection == mode ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selection == mode ? Color.sv.accent : Color.sv.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(mode.title)
                            .svHeadline()
                        if mode.isRecommended {
                            Text("Recommended")
                                .font(SVTypography.caption.weight(.semibold))
                                .foregroundStyle(Color.sv.canvas)
                                .padding(.horizontal, SVSpacing.sm)
                                .padding(.vertical, 2)
                                .background(Color.sv.accent, in: Capsule())
                        }
                    }
                    Text(mode.subtitle)
                        .font(SVTypography.caption)
                        .foregroundStyle(Color.sv.textSecondary)
                }
                Spacer(minLength: 0)
                SVQualityMeter(filled: mode.qualityBars)
            }
            .padding(SVSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: SVRadius.card, style: .continuous)
                    .fill(Color.sv.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: SVRadius.card, style: .continuous)
                            .strokeBorder(
                                selection == mode ? Color.sv.accent.opacity(0.7) : Color.clear,
                                lineWidth: 1.5
                            )
                    }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.ModePicker.option(mode))
        .accessibilityAddTraits(selection == mode ? [.isSelected] : [])
    }
}

#Preview {
    struct Host: View {
        @State private var mode = StemMode.four
        var body: some View {
            SVStemModePicker(selection: $mode)
                .padding()
                .background(Color.sv.canvas)
        }
    }
    return Host()
}
