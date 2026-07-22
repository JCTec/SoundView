import SwiftUI

/// Credits + privacy surface. Satisfies the release guardrails: the Demucs
/// attribution (Meta AI Research) lives here, and the "audio never leaves this
/// device" privacy promise is stated plainly (docs/RELEASE.md launch checklist).
struct AboutView: View {
    @Environment(\.appEnvironment) private var environment

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SVSpacing.xl) {
                VStack(alignment: .leading, spacing: SVSpacing.xs) {
                    Text("SoundView")
                        .svLargeTitle()
                    Text(version)
                        .svCaption()
                }

                card(title: "Your privacy") {
                    Text("Your audio never leaves this device. Import, separation, mixing, and "
                        + "export all run entirely on-device — nothing is uploaded, and no "
                        + "account is required.")
                    Text(environment.storageDisplaySentence)
                        .foregroundStyle(Color.sv.textSecondary)
                }

                card(title: "Separation model") {
                    Text("Studio separation uses Demucs (Hybrid Transformer Demucs, "
                        + "htdemucs_ft) by Meta AI Research. All four fine-tuned models "
                        + "are bundled and run entirely on this device.")
                    Text("Model: facebookresearch/demucs · Défossez et al.")
                        .foregroundStyle(Color.sv.textSecondary)
                }

                card(title: "Demucs — credits & license") {
                    Text(Self.demucsNotice)
                        .font(SVTypography.caption)
                        .foregroundStyle(Color.sv.textSecondary)
                        .textSelection(.enabled)
                }
            }
            .padding(SVSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.sv.canvas)
        .accessibilityIdentifier(A11yID.About.screen)
    }

    private func card(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SVSpacing.sm) {
            Text(title)
                .svHeadline()
            content()
                .font(SVTypography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SVSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SVRadius.card, style: .continuous)
                .fill(Color.sv.surface)
        )
    }

    static let demucsNotice = """
    Separation is powered by Demucs, © Meta Platforms, Inc. and affiliates \
    (github.com/facebookresearch/demucs). The Demucs source code is released \
    under the MIT License.

    The bundled htdemucs_ft model weights are released by Meta for research and \
    personal use under CC-BY-NC 4.0. SoundView is a free, open-source, \
    non-commercial project and bundles them on that basis. All inference runs \
    on-device; no audio is ever uploaded.

    Paper: Alexandre Défossez, “Hybrid Transformers for Music Source Separation,” \
    ISMIR 2023 (arXiv:2211.08553). Please cite it if you build on this work.
    """
}

#Preview {
    AboutView()
        .environment(\.appEnvironment, .preview)
}
