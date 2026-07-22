import SwiftUI
import UniformTypeIdentifiers

/// Root library — import primary, record secondary; stem badges on packages.
struct LibraryView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: ViewModel
    @State private var showRecorder = false
    @State private var showImporter = false
    @State private var showAbout = false
    @State private var stemMode: StemMode = .default

    init(fileStore: (any FileStoreProtocol)? = nil) {
        // Environment not available in init; PreviewFileStore until task loads real store.
        _viewModel = State(initialValue: ViewModel(fileStore: fileStore ?? PreviewFileStore()))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            listContent
            bottomBar
        }
        .background(Color.sv.canvas)
        .navigationTitle("Library")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .accessibilityIdentifier(A11yID.Library.screen)
        .task {
            viewModel.updateStore(environment.fileStore)
            // Ensure Idilio package exists before first load (DEBUG).
            await environment.seedDevelopmentLibraryIfNeeded()
            await environment.refreshStorageStatus()
            await viewModel.load()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleImportResult(result) }
        }
        .sheet(isPresented: $showRecorder) {
            RecorderView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAbout = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("About SoundView")
                .accessibilityIdentifier(A11yID.About.open)
            }
        }
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AboutView()
                    .navigationTitle("About")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showAbout = false }
                        }
                    }
            }
        }
    }

    private var listContent: some View {
        Group {
            if viewModel.songs.isEmpty {
                SVEmptyState(
                    systemImage: "music.note.list",
                    message: "Import a song to separate stems.",
                    actionTitle: "Import",
                    action: { showImporter = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(A11yID.Library.emptyState)
            } else {
                List {
                    Section {
                        SVSyncStatusLine(status: viewModel.syncStatus)
                        #if DEBUG
                        SVDebugBadge(label: "Idilio uses real Demucs stems")
                        #endif
                    }
                    ForEach(viewModel.songs) { song in
                        NavigationLink(value: song.id) {
                            SongRowView(song: song)
                        }
                        .accessibilityIdentifier(A11yID.Library.row(song.id))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteSong(id: song.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier(A11yID.Library.list)
            }
        }
        .navigationDestination(for: String.self) { id in
            SongDestinationView(songID: id, stemMode: $stemMode)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: SVSpacing.sm) {
            LinearGradient(
                colors: [Color.sv.canvas.opacity(0), Color.sv.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)

            HStack(spacing: SVSpacing.md) {
                SVCapsuleButton(
                    title: "Import",
                    systemImage: "square.and.arrow.down",
                    accessibilityID: A11yID.Library.importButton,
                    action: { showImporter = true }
                )

                SVCapsuleButton(
                    title: "Record",
                    systemImage: "mic.fill",
                    style: .secondary,
                    accessibilityID: A11yID.Library.recordButton,
                    action: { showRecorder = true }
                )
            }
            .padding(.horizontal, SVSpacing.lg)
            .padding(.bottom, SVSpacing.lg)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            _ = await viewModel.importAudio(from: url, mode: stemMode)
        case .failure(let error):
            viewModel.reportError(error.localizedDescription)
        }
    }

    // MARK: - Nested row (only used here)

    private struct SongRowView: View {
        let song: SongPackage

        var body: some View {
            HStack(spacing: SVSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .svHeadline()
                    Text(song.relativeDayLabel)
                        .svCaption()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    SVTimecodeLabel(seconds: song.duration)
                    if let count = song.stemCount {
                        SVStemBadge(count: count)
                    } else if let progress = song.separationProgress {
                        Text(SyncStatus.separating(progress: progress).sentence)
                            .svCaption()
                    } else {
                        Text(song.formatLabel)
                            .svCaption()
                    }
                }
            }
            .padding(.vertical, SVSpacing.xs)
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView()
    }
}
