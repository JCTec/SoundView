import SwiftUI

/// Every design-system tier on one screen — the taste checkpoint.
/// Preview this (dark + XXXL) before shipping any visual change; snapshot-tested
/// in Phase 4. Not shipped in release UI; it's a developer surface.
struct DesignSystemCatalog: View {
    @State private var volume: Float = 0.7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SVSpacing.xl) {
                section("Atoms — Palette") {
                    HStack(spacing: SVSpacing.sm) {
                        swatch("Pine 950", .sv.canvas)
                        swatch("Pine 900", .sv.surface)
                        swatch("Fern", .sv.accent)
                        swatch("Amber", .sv.edit)
                        swatch("Signal", .sv.record)
                    }
                }

                section("Atoms — Type") {
                    VStack(alignment: .leading, spacing: SVSpacing.xs) {
                        Text("Large Title").svLargeTitle()
                        Text("Headline").svHeadline()
                        Text("Body").svBody()
                        Text("Caption").svCaption()
                        Text("1:27.8").svTimecode(large: true)
                    }
                }

                section("Molecules") {
                    VStack(alignment: .leading, spacing: SVSpacing.md) {
                        HStack(spacing: SVSpacing.md) {
                            SVCapsuleButton(title: "Import", systemImage: "square.and.arrow.down") {}
                            SVCapsuleButton(title: "Record", systemImage: "mic.fill", style: .secondary) {}
                        }
                        HStack(spacing: SVSpacing.lg) {
                            SVMuteSoloButtons(isMuted: true, isSoloed: false, onMute: {}, onSolo: {})
                            SVMuteSoloButtons(isMuted: false, isSoloed: true, onMute: {}, onSolo: {})
                            SVStemBadge(count: 5)
                        }
                        SVVolumeSlider(volume: $volume, tint: LaneColorMath.color(forStemIndex: 2))
                            .frame(width: 200)
                        HStack(spacing: SVSpacing.md) {
                            SVDebugBadge(label: "catalog sample")
                            SVReturnToPlayheadChip {}
                        }
                    }
                }

                section("Organisms") {
                    VStack(alignment: .leading, spacing: SVSpacing.md) {
                        SVLoadingWave(color: LaneColorMath.color(forStemIndex: 3))
                            .frame(height: 56)
                        SVTimeRuler(visible: .init(start: 58, end: 70))
                        SVWaveformCanvas(
                            waveform: Self.sampleTiers,
                            visible: .init(start: 60, end: 72),
                            playhead: 64,
                            color: LaneColorMath.color(forStemIndex: 0)
                        )
                        .frame(height: 80)
                        SVTransportBar(isPlaying: false, onSkipBack: {}, onTogglePlay: {}, onSkipForward: {})
                        SVSyncStatusLine(status: .syncedWithiCloud)
                        SVQualityPicker(selection: .constant(.studio), isAvailable: { $0 == .studio })
                    }
                }

                section("Lane colors (golden-angle, red band skipped)") {
                    HStack(spacing: SVSpacing.xs) {
                        ForEach(0..<10, id: \.self) { index in
                            RoundedRectangle(cornerRadius: SVRadius.badge)
                                .fill(LaneColorMath.color(forStemIndex: index))
                                .frame(width: 32, height: 32)
                        }
                    }
                }
            }
            .padding(SVSpacing.xl)
        }
        .background(Color.sv.canvas)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SVSpacing.sm) {
            Text(title)
                .font(SVTypography.caption.weight(.semibold))
                .foregroundStyle(Color.sv.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: SVSpacing.xs) {
            RoundedRectangle(cornerRadius: SVRadius.badge)
                .fill(color)
                .frame(width: 48, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: SVRadius.badge)
                        .strokeBorder(Color.sv.textPrimary.opacity(0.15))
                )
            Text(name)
                .font(SVTypography.caption)
                .foregroundStyle(Color.sv.textSecondary)
        }
    }

    private static let sampleTiers: WaveformTiers = {
        let peaks = (0..<2_048).map { index -> PeakDecimation.Peak in
            let value = Float(abs(sin(Double(index) * 0.045)) * 0.75 + 0.12)
            return PeakDecimation.Peak(min: -value, max: value)
        }
        return WaveformTiers(tiers: [2_048: peaks], duration: 300)
    }()
}

#Preview("Catalog · Dark") {
    DesignSystemCatalog()
}

#Preview("Catalog · XXXL") {
    DesignSystemCatalog()
        .environment(\.dynamicTypeSize, .accessibility3)
}
