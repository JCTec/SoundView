import SwiftUI

/// Separation engine selection (single studio engine: Demucs). Kept for the
/// design-system catalog; the Separate screen no longer needs a multi-tier picker.
struct SVQualityPicker: View {
    @Binding var selection: SeparationQuality
    var isAvailable: (SeparationQuality) -> Bool = { _ in true }

    var body: some View {
        VStack(alignment: .leading, spacing: SVSpacing.md) {
            Text("Quality")
                .svHeadline()

            VStack(spacing: SVSpacing.sm) {
                ForEach(SeparationQuality.allCases) { quality in
                    row(quality)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.QualityPicker.picker)
    }

    private func row(_ quality: SeparationQuality) -> some View {
        Button {
            selection = quality
        } label: {
            HStack(spacing: SVSpacing.md) {
                Image(systemName: selection == quality ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selection == quality ? Color.sv.accent : Color.sv.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(quality.title)
                            .svHeadline()
                        if !isAvailable(quality) {
                            Text("Not installed")
                                .font(SVTypography.caption.weight(.semibold))
                                .foregroundStyle(Color.sv.textSecondary)
                                .padding(.horizontal, SVSpacing.sm)
                                .padding(.vertical, 2)
                                .background(Color.sv.surface, in: Capsule())
                        }
                    }
                    Text(quality.subtitle)
                        .font(SVTypography.caption)
                        .foregroundStyle(Color.sv.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(SVSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: SVRadius.card, style: .continuous)
                    .fill(Color.sv.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: SVRadius.card, style: .continuous)
                            .strokeBorder(
                                selection == quality ? Color.sv.accent.opacity(0.7) : Color.clear,
                                lineWidth: 1.5
                            )
                    }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.QualityPicker.option(quality))
        .accessibilityAddTraits(selection == quality ? [.isSelected] : [])
    }
}

#Preview {
    struct Host: View {
        @State private var quality = SeparationQuality.studio
        var body: some View {
            SVQualityPicker(selection: $quality, isAvailable: { $0 == .studio })
                .padding()
                .background(Color.sv.canvas)
        }
    }
    return Host()
}
