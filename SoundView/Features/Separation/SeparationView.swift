import SwiftUI

/// On-device separation wait UX — materializing stems, honest progress.
/// Single studio engine (Meta Demucs); no quality/install picker.
struct SeparationView: View {
    let song: SongPackage
    @Binding var mode: StemMode
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ViewModel

    init(song: SongPackage, mode: Binding<StemMode>) {
        self.song = song
        _mode = mode
        _viewModel = State(initialValue: ViewModel(song: song, mode: mode.wrappedValue))
    }

    var body: some View {
        VStack(spacing: SVSpacing.xl) {
            Text("SEPARATING")
                .font(SVTypography.caption.weight(.bold))
                .foregroundStyle(Color.sv.accent)
                .tracking(2)

            Text(song.title)
                .svLargeTitle()

            Text("Studio separation · on this device")
                .svCaption()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            SVStemModePicker(selection: $mode)
                .disabled(viewModel.isRunning)
                .padding(.horizontal)

            separatingSection

            Spacer()

            footerButton
        }
        .padding(.top, SVSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sv.canvas)
        .accessibilityIdentifier(A11yID.Separation.screen)
        .task(id: mode.rawValue) {
            viewModel.mode = mode
            viewModel.bind(
                separator: environment.stemSeparator,
                catalog: environment.modelCatalog
            )
            await viewModel.startSeparation()
        }
        .onChange(of: mode) { _, newValue in
            viewModel.mode = newValue
        }
    }

    private var separatingSection: some View {
        VStack(spacing: SVSpacing.xl) {
            VStack(alignment: .leading, spacing: SVSpacing.sm) {
                ForEach(viewModel.foundStems) { stem in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.sv.accent)
                        Text(stem.name)
                            .svHeadline()
                        if stem.isLowEnergy {
                            Text("Low energy")
                                .svCaption()
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(SVAnimation.chrome, value: viewModel.foundStems.count)
            .frame(maxWidth: 320, alignment: .leading)

            ProgressView(value: viewModel.progress)
                .tint(Color.sv.accent)
                .padding(.horizontal, SVSpacing.xxl)

            Text(viewModel.progressLabel)
                .svCaption()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var footerButton: some View {
        Group {
            if viewModel.isFinished {
                SVCapsuleButton(
                    title: "Done",
                    systemImage: "checkmark",
                    accessibilityID: A11yID.Separation.cancel,
                    action: { dismiss() }
                )
            } else {
                SVCapsuleButton(
                    title: "Cancel",
                    systemImage: "xmark",
                    accessibilityID: A11yID.Separation.cancel,
                    action: {
                        viewModel.cancel()
                        dismiss()
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, SVSpacing.xxl)
    }
}
