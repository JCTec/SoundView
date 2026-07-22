import SwiftUI

/// Compact (iPhone) stacked stem lanes — the same `StemPlayerModel` and wave
/// physics as the desk, composed as cards. Drag any wave: all lanes scroll.
struct StemView: View {
    let song: SongPackage
    @Environment(\.appEnvironment) private var environment
    @State private var player = StemPlayerModel()
    @State private var exportRequest: StemExportRequest?

    var body: some View {
        VStack(spacing: 0) {
            if let loadError = player.loadError {
                Text(loadError)
                    .svCaption()
                    .foregroundStyle(Color.sv.edit)
                    .padding()
            }

            TimelineView(.animation(paused: !player.isPlaying)) { timeline in
                let visible = player.visibleRange(at: timeline.date)
                let playhead = player.clock.time(at: timeline.date)

                VStack(spacing: 0) {
                    header(playhead: playhead)
                    SVTimeRuler(visible: visible)
                        .padding(.horizontal, SVSpacing.md)

                    ScrollView {
                        LazyVStack(spacing: SVSpacing.sm) {
                            ForEach(player.lanes) { lane in
                                StemLaneView(
                                    lane: lane,
                                    layout: .inline,
                                    visible: visible,
                                    playhead: playhead,
                                    anySolo: player.anySolo,
                                    gestureModel: player,
                                    onMute: { player.toggleMute(id: lane.id) },
                                    onSolo: { player.toggleSolo(id: lane.id) },
                                    onVolume: { player.setVolume(id: lane.id, volume: $0) },
                                    onExport: { requestExport(pickedStemID: lane.id) }
                                )
                                .accessibilityIdentifier(A11yID.Stem.lane(lane.id))
                            }
                        }
                        .padding(.horizontal, SVSpacing.md)
                        .padding(.bottom, SVSpacing.xxl)
                    }
                    .overlay(alignment: .topTrailing) {
                        if player.showsReturnChip {
                            SVReturnToPlayheadChip {
                                withAnimation(SVAnimation.spring) { player.returnToPlayhead() }
                            }
                            .padding(SVSpacing.md)
                        }
                    }
                }
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
                    requestExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityIdentifier(A11yID.Stem.export)
            }
        }
        .accessibilityIdentifier(A11yID.Stem.screen)
        .sheet(item: $exportRequest) { request in
            StemExportSheet(title: song.title, stems: request.stems, initialSelection: request.selection)
        }
        .task {
            await player.load(
                song: song,
                mixer: environment.stemMixer,
                fileStore: environment.fileStore
            )
        }
        .onDisappear { player.teardown() }
    }

    private func requestExport(pickedStemID: String? = nil) {
        Task {
            let stems = await StemExportInputs.build(
                song: song, player: player, fileStore: environment.fileStore
            )
            let selection: StemExportSelection = pickedStemID.map { .pickedStems([$0]) } ?? .currentMix
            exportRequest = StemExportRequest(stems: stems, selection: selection)
        }
    }

    private func header(playhead: TimeInterval) -> some View {
        HStack {
            Text("\(song.stemCount ?? song.stems.count) stems · \(TimeFormatting.timecode(seconds: song.duration))")
                .svCaption()
            Spacer()
            SVTimecodeLabel(seconds: playhead, showMillis: true)
        }
        .padding(.horizontal, SVSpacing.lg)
        .padding(.vertical, SVSpacing.sm)
    }

    private var footer: some View {
        SVTransportBar(
            isPlaying: player.isPlaying,
            onSkipBack: { player.skip(by: -15) },
            onTogglePlay: { player.togglePlay() },
            onSkipForward: { player.skip(by: 15) }
        )
        .padding(.vertical, SVSpacing.md)
        .frame(maxWidth: .infinity)
        .background(Color.sv.surface.opacity(0.9))
    }
}

#Preview {
    NavigationStack {
        StemView(song: SongPackage.samples[0])
    }
}
