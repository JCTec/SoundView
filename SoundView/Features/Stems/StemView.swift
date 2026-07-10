import SwiftUI

/// Compact (iPhone) stacked stem lanes — shared viewport physics.
struct StemView: View {
    let song: SongPackage
    @State private var viewModel: ViewModel

    init(song: SongPackage) {
        self.song = song
        _viewModel = State(initialValue: ViewModel(song: song))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: SVSpacing.sm) {
                    ForEach(viewModel.lanes) { lane in
                        StemLaneView(
                            lane: lane,
                            layout: .inline,
                            onMute: { viewModel.toggleMute(id: lane.id) },
                            onSolo: { viewModel.toggleSolo(id: lane.id) },
                            onVolume: { viewModel.setVolume(id: lane.id, volume: $0) }
                        )
                        .accessibilityIdentifier(A11yID.Stem.lane(lane.id))
                    }
                }
                .padding(.horizontal, SVSpacing.md)
                .padding(.bottom, SVSpacing.xxl)
            }
            footer
        }
        .background(Color.sv.canvas)
        .navigationTitle(song.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.requestExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityIdentifier(A11yID.Stem.export)
            }
        }
        .accessibilityIdentifier(A11yID.Stem.screen)
    }

    private var header: some View {
        HStack {
            Text("\(song.stemCount ?? song.stems.count) stems")
                .svCaption()
            Spacer()
            SVTimecodeLabel(seconds: viewModel.playhead, showMillis: true)
        }
        .padding(.horizontal, SVSpacing.lg)
        .padding(.vertical, SVSpacing.sm)
    }

    private var footer: some View {
        VStack(spacing: SVSpacing.sm) {
            SVTransportBar(
                isPlaying: viewModel.isPlaying,
                onSkipBack: { viewModel.skip(by: -15) },
                onTogglePlay: { viewModel.togglePlay() },
                onSkipForward: { viewModel.skip(by: 15) }
            )
            .padding(.bottom, SVSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(Color.sv.surface.opacity(0.9))
    }
}

#Preview {
    NavigationStack {
        StemView(song: SongPackage.samples[0])
    }
}
