import SwiftUI

/// Visual quality bars for stem-mode selection (4/6 = best).
struct SVQualityMeter: View {
    /// Filled segments out of `total` (1…5).
    let filled: Int
    var total: Int = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < filled ? Color.sv.accent : Color.sv.textSecondary.opacity(0.25))
                    .frame(width: 8, height: 14)
            }
        }
        .accessibilityLabel("Quality \(filled) of \(total)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        HStack { Text("4 stems"); SVQualityMeter(filled: 5) }
        HStack { Text("Max"); SVQualityMeter(filled: 2) }
    }
    .foregroundStyle(Color.sv.textPrimary)
    .padding()
    .background(Color.sv.canvas)
}
