import SwiftUI

/// On-device separation wait UX — materializing stems, honest progress.
struct SeparationView: View {
    let song: SongPackage
    @Binding var mode: StemMode
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

            Text("On this device · works offline")
                .svCaption()

            SVStemModePicker(selection: $mode)
                .disabled(viewModel.isRunning)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: SVSpacing.sm) {
                ForEach(viewModel.foundStems) { stem in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.sv.accent)
                        Text(stem.name)
                            .svHeadline()
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SVSpacing.xl)
            .animation(.easeOut, value: viewModel.foundStems.map(\.id))

            VStack(spacing: SVSpacing.xs) {
                ProgressView(value: viewModel.progress)
                    .tint(Color.sv.accent)
                    .accessibilityIdentifier(A11yID.Separation.progress)
                Text(viewModel.progressLabel)
                    .svCaption()
                Text("You can leave this screen — separation continues in the background and we'll notify you.")
                    .font(SVTypography.caption)
                    .foregroundStyle(Color.sv.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.horizontal, SVSpacing.xl)

            Spacer()

            SVCapsuleButton(
                title: "Cancel",
                style: .secondary,
                action: { viewModel.cancel() }
            )
            .padding()
            .accessibilityIdentifier(A11yID.Separation.cancel)
        }
        .padding(.top, SVSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sv.canvas)
        .accessibilityIdentifier(A11yID.Separation.screen)
        .task {
            viewModel.mode = mode
            await viewModel.startDemoProgress()
        }
        .onChange(of: mode) { _, newValue in
            viewModel.mode = newValue
        }
    }
}

#Preview {
    SeparationView(song: SongPackage.samples[1], mode: .constant(.four))
}
