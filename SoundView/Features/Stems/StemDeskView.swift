import SwiftUI

/// iPad/Mac detail: the stem desk. Fixed header columns on the left, one shared
/// wave viewport on the right, a single needle spanning every lane, transport
/// bottom-center (Large Screens PDF). Lanes flex to fill the available height.
struct StemDeskView: View {
    let songID: String?
    @Binding var focusedStemID: String?
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: ViewModel
    @State private var stemMode: StemMode = .default
    @State private var exportRequest: StemExportRequest?

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
                    SeparationView(song: song, mode: $stemMode)
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
        .sheet(item: $exportRequest) { request in
            StemExportSheet(
                title: viewModel.song?.title ?? "Stems",
                stems: request.stems,
                initialSelection: request.selection
            )
        }
        .task(id: songID) {
            viewModel.bind(mixer: environment.stemMixer, fileStore: environment.fileStore)
            await viewModel.load(songID: songID, store: environment.fileStore)
        }
        .onChange(of: focusedStemID) { _, newValue in
            viewModel.focusStem(id: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .soundViewPackageDidChange)) { note in
            guard let id = note.userInfo?["id"] as? String, id == songID else { return }
            Task { await viewModel.load(songID: songID, store: environment.fileStore) }
        }
        .onDisappear { viewModel.teardown() }
    }

    // MARK: - Separated desk

    private func separatedDesk(_ song: SongPackage) -> some View {
        let player = viewModel.player
        return VStack(spacing: 0) {
            deskChrome(song)

            TimelineView(.animation(paused: !player.isPlaying)) { timeline in
                let visible = player.visibleRange(at: timeline.date)
                let playhead = player.clock.time(at: timeline.date)

                VStack(spacing: 0) {
                    // Ruler sits over the wave column only.
                    SVTimeRuler(visible: visible)
                        .padding(.leading, SVSpacing.deskHeaderColumn)

                    laneColumn(song: song, player: player, visible: visible, playhead: playhead)
                }
                // One needle across ruler + every lane (never per-lane).
                .overlay(alignment: .topLeading) {
                    needle(player: player, at: timeline.date)
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

            transport(player)
        }
    }

    private func laneColumn(
        song: SongPackage, player: StemPlayerModel,
        visible: ViewportMath.Range, playhead: TimeInterval
    ) -> some View {
        GeometryReader { proxy in
            let count = max(1, player.lanes.count)
            let laneHeight = max(
                SVSpacing.deskLaneMinHeight,
                min(SVSpacing.deskLaneMaxHeight, proxy.size.height / CGFloat(count))
            )
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(player.lanes) { lane in
                        StemLaneView(
                            lane: lane,
                            layout: .desk,
                            visible: visible,
                            playhead: playhead,
                            anySolo: player.anySolo,
                            gestureModel: player,
                            onMute: { player.toggleMute(id: lane.id) },
                            onSolo: { player.toggleSolo(id: lane.id) },
                            onVolume: { player.setVolume(id: lane.id, volume: $0) },
                            onExport: { requestExport(song: song, pickedStemID: lane.id) }
                        )
                        .frame(height: laneHeight)
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
        }
    }

    /// The single cross-lane playhead needle (design: "spans all lanes").
    private func needle(player: StemPlayerModel, at date: Date) -> some View {
        GeometryReader { proxy in
            let waveWidth = max(1, proxy.size.width - SVSpacing.deskHeaderColumn)
            let x = SVSpacing.deskHeaderColumn + player.needleX(at: date, width: waveWidth)
            Rectangle()
                .fill(Color.sv.textPrimary.opacity(0.9))
                .frame(width: SVWaveMetrics.needleWidth)
                .offset(x: x - SVWaveMetrics.needleWidth / 2)
        }
        .allowsHitTesting(false)
    }

    private func deskChrome(_ song: SongPackage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .svHeadline()
                Text("\(song.stemCount ?? 0) stems · \(TimeFormatting.timecode(seconds: song.duration))")
                    .svCaption()
            }
            Spacer()
            Button {
                requestExport(song: song)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.sv.textPrimary)
                    .frame(width: SVSpacing.minHit, height: SVSpacing.minHit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export")
            .accessibilityIdentifier(A11yID.Stem.export)
        }
        .padding(.horizontal, SVSpacing.lg)
        .padding(.vertical, SVSpacing.md)
        .background(Color.sv.surface.opacity(0.9))
    }

    private func requestExport(song: SongPackage, pickedStemID: String? = nil) {
        Task {
            let stems = await StemExportInputs.build(
                song: song, player: viewModel.player, fileStore: environment.fileStore
            )
            let selection: StemExportSelection = pickedStemID.map { .pickedStems([$0]) } ?? .currentMix
            exportRequest = StemExportRequest(stems: stems, selection: selection)
        }
    }

    /// Bottom-center transport with the live timecode beside it (iPad desk mock).
    private func transport(_ player: StemPlayerModel) -> some View {
        HStack(spacing: SVSpacing.xl) {
            TimelineView(.animation(paused: !player.isPlaying)) { timeline in
                SVTimecodeLabel(
                    seconds: player.clock.time(at: timeline.date),
                    large: true,
                    showMillis: true
                )
            }
            SVTransportBar(
                isPlaying: player.isPlaying,
                onSkipBack: { player.skip(by: -15) },
                onTogglePlay: { player.togglePlay() },
                onSkipForward: { player.skip(by: 15) }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SVSpacing.md)
        .background(Color.sv.surface.opacity(0.9))
    }
}

#Preview {
    StemDeskView(songID: "midnight", focusedStemID: .constant(nil))
        .environment(\.appEnvironment, .preview)
}
