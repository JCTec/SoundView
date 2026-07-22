import SwiftUI

/// Fern capsule showing stem count on library rows.
struct SVStemBadge: View {
    let count: Int

    var body: some View {
        Text("\(count) stems")
            .font(SVTypography.caption.weight(.semibold))
            .foregroundStyle(Color.sv.canvas)
            .padding(.horizontal, SVSpacing.sm)
            .padding(.vertical, SVSpacing.xs)
            .background(Color.sv.accent, in: Capsule())
            .accessibilityLabel("\(count) stems")
    }
}

#Preview {
    SVStemBadge(count: 5)
        .padding()
        .background(Color.sv.canvas)
}
