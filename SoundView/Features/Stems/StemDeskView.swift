import SwiftUI

/// iPad/Mac detail: stem desk with header columns + shared wave area.
struct StemDeskView: View {
    let songID: String?
    @Binding var focusedStemID: String?
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: ViewModel
    @State private var stemMode: StemMode = .default

    init(songID: String?, focusedStemID: Binding<String?>) {
        self.songID = songID
        _focusedStemID = focusedStemID
        _viewModel = State(initialValue: ViewModel(songID: songID))
    }

    var body: some View {
        Group {
            if let song = viewModel.song {
                if song.isSeparated {
                    separatedDesk(song)
                } else {
                    unseparatedDesk(song)
                }
            } else {
                SVEmptyState(
                    systemImage: "sidebar.left",
                    message: "Select a song from the library."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.sv.canvas)
        .accessibilityIdentifier(A11yID.Stem.desk)
        .task(id: songID) {
            await viewModel.load(songID: songID, store: environment.fileStore)
        }
        .onChange(of: focusedStemID) { _, newValue in
            viewModel.focusStem(id: newValue)
        }
    }

    private func separatedDesk(_ song: SongPackage) -> some View {
        VStack(spacing: 0) {
            deskChrome(song)
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(viewModel.lanes) { lane in
                        StemLaneView(
                            lane: lane,
                            layout: .desk,
                            onMute: { viewModel.toggleMute(id: lane.id) },
                            onSolo: { viewModel.toggleSolo(id: lane.id) },
                            onVolume: { viewModel.setVolume(id: lane.id, volume: $0) }
                        )
                        .accessibilityIdentifier(A11yID.Stem.lane(lane.id))
                        .overlay {
                            if focusedStemID == lane.id {
                                Rectangle()
                                    .strokeBorder(Color.sv.accent.opacity(0.5), lineWidth: 1)
                            }
                        }
                    }
                }
            }
            SVTransportBar(
                isPlaying: viewModel.isPlaying,
                onSkipBack: { viewModel.skip(by: -15) },
                onTogglePlay: { viewModel.togglePlay() },
                onSkipForward: { viewModel.skip(by: 15) }
            )
            .padding()
        }
    }

    private func unseparatedDesk(_ song: SongPackage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SVSpacing.xl) {
                Text(song.title)
                    .svLargeTitle()
                Text("Not separated yet")
                    .svCaption()
                SVStemModePicker(selection: $stemMode)
                SVCapsuleButton(
                    title: "Separate",
                    systemImage: "waveform.badge.magnifyingglass",
                    style: .edit,
                    action: { viewModel.beginSeparation(mode: stemMode) }
                )
                .frame(maxWidth: 360)
            }
            .padding(SVSpacing.xxl)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    private func deskChrome(_ song: SongPackage) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title)
                    .svHeadline()
                Text("\(song.stemCount ?? 0) stems · \(TimeFormatting.timecode(seconds: song.duration))")
                    .svCaption()
            }
            Spacer()
            SVTimecodeLabel(seconds: viewModel.playhead, large: true, showMillis: true)
            Button {
                viewModel.requestExport()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityIdentifier(A11yID.Stem.export)
        }
        .padding(SVSpacing.lg)
        .background(Color.sv.surface.opacity(0.9))
    }
}

#Preview {
    StemDeskView(songID: "midnight", focusedStemID: .constant(nil))
        .environment(\.appEnvironment, .preview)
}
