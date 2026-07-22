import SwiftUI

/// Delivers the "Every stem out" promise: current mix / all stems / a picked
/// stem, WAV or M4A, then a system share sheet. Progress + cancellation.
struct StemExportSheet: View {
    let title: String
    let stems: [StemExporter.Stem]
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ViewModel

    init(title: String, stems: [StemExporter.Stem], initialSelection: StemExportSelection = .currentMix) {
        self.title = title
        self.stems = stems
        _viewModel = State(initialValue: ViewModel(title: title, stems: stems, selection: initialSelection))
    }

    var body: some View {
        VStack(spacing: SVSpacing.xl) {
            Text("EXPORT")
                .font(SVTypography.caption.weight(.bold))
                .foregroundStyle(Color.sv.accent)
                .tracking(2)
            Text(viewModel.headline)
                .svLargeTitle()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if viewModel.showsSelection {
                labeledGroup("What") {
                    optionCapsule("Current mix", isSelected: viewModel.selection == .currentMix,
                                  id: "currentMix") { viewModel.selection = .currentMix }
                    optionCapsule("All stems", isSelected: viewModel.selection == .allStems,
                                  id: "allStems") { viewModel.selection = .allStems }
                }
            }

            labeledGroup("Format") {
                ForEach(StemExportFormat.allCases) { format in
                    optionCapsule(format.title, isSelected: viewModel.format == format,
                                  id: format.rawValue) { viewModel.format = format }
                }
            }

            Spacer()

            footer
        }
        .padding(SVSpacing.xl)
        .padding(.top, SVSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sv.canvas)
        .accessibilityIdentifier(A11yID.Stem.exportSheet)
    }

    // MARK: - Footer (run / progress / share)

    @ViewBuilder
    private var footer: some View {
        if let url = viewModel.resultURL {
            VStack(spacing: SVSpacing.md) {
                Text("Ready to share.")
                    .svCaption()
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(SVTypography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: SVSpacing.primaryCTAHeight)
                        .background(Color.sv.accent, in: Capsule())
                        .foregroundStyle(Color.sv.canvas)
                }
                .accessibilityIdentifier(A11yID.Stem.exportShare)
                SVCapsuleButton(title: "Done", style: .secondary) { dismiss() }
            }
        } else if viewModel.isExporting {
            VStack(spacing: SVSpacing.sm) {
                ProgressView(value: viewModel.progress).tint(Color.sv.accent)
                SVCapsuleButton(title: "Cancel", style: .secondary) { viewModel.cancel() }
            }
        } else {
            VStack(spacing: SVSpacing.sm) {
                if let error = viewModel.errorMessage {
                    Text(error).svCaption().multilineTextAlignment(.center)
                }
                SVCapsuleButton(
                    title: "Export",
                    systemImage: "square.and.arrow.up",
                    accessibilityID: A11yID.Stem.exportRun
                ) { viewModel.export() }
            }
        }
    }

    // MARK: - Building blocks

    private func labeledGroup(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SVSpacing.sm) {
            Text(label).svHeadline()
            HStack(spacing: SVSpacing.sm) { content() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionCapsule(
        _ title: String, isSelected: Bool, id: String, action: @escaping () -> Void
    ) -> some View {
        SVCapsuleButton(
            title: title,
            style: isSelected ? .primary : .secondary,
            accessibilityID: A11yID.Stem.exportOption(id),
            action: action
        )
    }
}

#Preview {
    StemExportSheet(title: "Idilio", stems: [])
}
