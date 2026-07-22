import SwiftUI

/// The ONLY way development-time affordances appear in UI (amendment A4).
/// Rules: wrap the call site in `#if DEBUG`, and never place debug info as plain
/// text in production layouts — always through this badge, so it reads as tooling.
struct SVDebugBadge: View {
    let label: String

    var body: some View {
        HStack(spacing: SVSpacing.xs) {
            Text("DEBUG")
                .font(SVTypography.caption.weight(.bold).monospaced())
                .foregroundStyle(Color.sv.canvas)
                .padding(.horizontal, SVSpacing.xs + 2)
                .padding(.vertical, 2)
                .background(Color.sv.edit, in: RoundedRectangle(cornerRadius: SVRadius.badge))
            Text(label)
                .font(SVTypography.caption)
                .foregroundStyle(Color.sv.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Debug: \(label)")
    }
}

#Preview {
    SVDebugBadge(label: "real Demucs stems")
        .padding()
        .background(Color.sv.canvas)
}
