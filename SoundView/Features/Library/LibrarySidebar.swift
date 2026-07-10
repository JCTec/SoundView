import SwiftUI
import UniformTypeIdentifiers

/// Regular/large library sidebar — songs + open-song stem jump list (no reorder).
struct LibrarySidebar: View {
    @Environment(\.appEnvironment) private var environment
    @Binding var selectedSongID: String?
    @Binding var selectedStemID: String?
    @State private var viewModel: LibraryView.ViewModel
    @State private var showRecorderSlideOver = false
    @State private var showImporter = false
    @State private var stemMode: StemMode = .default

    init(
        selectedSongID: Binding<String?>,
        selectedStemID: Binding<String?>,
        fileStore: (any FileStoreProtocol)? = nil
    ) {
        _selectedSongID = selectedSongID
        _selectedStemID = selectedStemID
        _viewModel = State(initialValue: LibraryView.ViewModel(fileStore: fileStore ?? PreviewFileStore()))
    }

    var body: some View {
        List(selection: $selectedSongID) {
            Section {
                SVSyncStatusLine(status: viewModel.syncStatus)
            }

            Section("Songs") {
                ForEach(viewModel.songs) { song in
                    songRow(song)
                        .tag(song.id)
                        .accessibilityIdentifier(A11yID.Library.row(song.id))
                        .contextMenu {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteSong(id: song.id)
                                    if selectedSongID == song.id {
                                        selectedSongID = viewModel.songs.first?.id
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }

            if let open = openSong, open.isSeparated {
                Section("Stems") {
                    ForEach(open.stems) { stem in
                        Button {
                            selectedStemID = stem.id
                        } label: {
                            Label(stem.name, systemImage: "waveform")
                        }
                        .accessibilityIdentifier(A11yID.Library.stemJump(stem.id))
                    }
                }
            }
        }
        .navigationTitle("Library")
        .accessibilityIdentifier(A11yID.Library.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: SVSpacing.sm) {
                SVCapsuleButton(
                    title: "Import",
                    systemImage: "square.and.arrow.down",
                    action: { showImporter = true }
                )
                .accessibilityIdentifier(A11yID.Library.importButton)

                SVCapsuleButton(
                    title: "Record",
                    systemImage: "mic.fill",
                    style: .secondary,
                    action: { showRecorderSlideOver = true }
                )
                .accessibilityIdentifier(A11yID.Library.recordButton)
            }
            .padding()
            .background(Color.sv.canvas.opacity(0.95))
        }
        .task {
            viewModel.updateStore(environment.fileStore)
            await environment.refreshStorageStatus()
            await viewModel.load()
            if selectedSongID == nil {
                selectedSongID = viewModel.songs.first?.id
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            Task {
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if let package = await viewModel.importAudio(from: url, mode: stemMode) {
                        selectedSongID = package.id
                    }
                case .failure(let error):
                    viewModel.reportError(error.localizedDescription)
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showRecorderSlideOver) {
            // Slide-over style presentation so library remains in the split context.
            RecorderView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        #else
        .sheet(isPresented: $showRecorderSlideOver) {
            RecorderView()
                .frame(minWidth: 400, minHeight: 480)
        }
        #endif
    }

    private var openSong: SongPackage? {
        viewModel.songs.first { $0.id == selectedSongID }
    }

    private func songRow(_ song: SongPackage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .svHeadline()
                if let progress = song.separationProgress {
                    Text(SyncStatus.separating(progress: progress).sentence)
                        .svCaption()
                } else {
                    Text(song.relativeDayLabel)
                        .svCaption()
                }
            }
            Spacer()
            if let count = song.stemCount {
                SVStemBadge(count: count)
            } else {
                Text(song.formatLabel)
                    .svCaption()
            }
        }
    }
}

#Preview {
    NavigationSplitView {
        LibrarySidebar(selectedSongID: .constant("midnight"), selectedStemID: .constant(nil))
    } detail: {
        Text("Desk")
            .foregroundStyle(Color.sv.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.sv.canvas)
    }
}
