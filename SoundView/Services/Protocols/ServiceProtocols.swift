import Foundation

/// File package access — iCloud folder is the preferred source of truth.
/// Implementations must never surface absolute paths to UI layers.
protocol FileStoreProtocol: Sendable {
    func listSongs() async throws -> [SongPackage]
    func song(id: String) async throws -> SongPackage?
    func importAudio(from url: URL, autoSeparate mode: StemMode) async throws -> SongPackage
    func deleteSong(id: String) async throws
    func currentSyncStatus() async -> SyncStatus
    func storageDisplaySentence() async -> String
    func updateSeparation(
        id: String,
        status: SeparationStatus,
        progress: Double,
        stems: [StemFileEntry]?
    ) async throws -> SongPackage
    func originalAudioURL(id: String) async throws -> URL
    func packageDirectoryURL(id: String) async throws -> URL
    func stemAudioURLs(id: String) async throws -> [(id: String, url: URL)]
}

/// On-device stem separation.
protocol StemSeparating: Sendable {
    func separate(
        packageID: String,
        mode: StemMode,
        quality: SeparationQuality
    ) -> AsyncThrowingStream<StemEvent, Error>
}

extension StemSeparating {
    /// Back-compat convenience — defaults to the always-available Standard engine.
    func separate(packageID: String, mode: StemMode) -> AsyncThrowingStream<StemEvent, Error> {
        separate(packageID: packageID, mode: mode, quality: .studio)
    }
}

enum StemEvent: Sendable {
    case progress(Double, eta: TimeInterval?)
    case found(StemDescriptor)
    case finished([StemDescriptor])
}

/// Multi-lane playback mixer.
protocol StemMixing: Sendable {
    func loadStems(_ stems: [(id: String, url: URL)], duration: TimeInterval) async throws
    func setPlaying(_ playing: Bool) async
    func seek(to time: TimeInterval) async
    func setGains(_ gains: [Float]) async
    /// Transport anchor for frame-driven playhead rendering.
    func playbackClock() async -> PlaybackClock
}

// MARK: - Preview / mock

/// Preview store for DesignSystem-first development and SwiftUI previews.
final class PreviewFileStore: FileStoreProtocol, @unchecked Sendable {
    private var songs: [SongPackage]
    var syncStatus: SyncStatus
    var storageSentence: String

    init(
        songs: [SongPackage] = SongPackage.samples,
        syncStatus: SyncStatus = .syncedWithiCloud,
        storageSentence: String = "SoundView in iCloud Drive"
    ) {
        self.songs = songs
        self.syncStatus = syncStatus
        self.storageSentence = storageSentence
    }

    func listSongs() async throws -> [SongPackage] {
        songs
    }

    func song(id: String) async throws -> SongPackage? {
        songs.first { $0.id == id }
    }

    func importAudio(from url: URL, autoSeparate mode: StemMode) async throws -> SongPackage {
        let package = SongPackage(
            id: UUID().uuidString,
            title: url.deletingPathExtension().lastPathComponent,
            duration: 0,
            stemCount: nil,
            formatLabel: url.pathExtension.uppercased(),
            relativeDayLabel: "Today",
            stems: [],
            separationProgress: nil
        )
        songs.insert(package, at: 0)
        return package
    }

    func deleteSong(id: String) async throws {
        songs.removeAll { $0.id == id }
    }

    func currentSyncStatus() async -> SyncStatus {
        syncStatus
    }

    func storageDisplaySentence() async -> String {
        storageSentence
    }

    func updateSeparation(
        id: String,
        status: SeparationStatus,
        progress: Double,
        stems: [StemFileEntry]?
    ) async throws -> SongPackage {
        guard var song = songs.first(where: { $0.id == id }) else {
            throw FileStoreError.packageNotFound(id)
        }
        if let stems {
            song.stems = stems.map {
                StemDescriptor(id: $0.id, name: $0.name, index: $0.index, isLowEnergy: $0.isLowEnergy)
            }
            song.stemCount = stems.isEmpty ? nil : stems.count
        }
        song.separationProgress = status == .running ? progress : nil
        if let index = songs.firstIndex(where: { $0.id == id }) {
            songs[index] = song
        }
        return song
    }

    func originalAudioURL(id: String) async throws -> URL {
        throw FileStoreError.packageNotFound(id)
    }

    func packageDirectoryURL(id: String) async throws -> URL {
        throw FileStoreError.packageNotFound(id)
    }

    func stemAudioURLs(id: String) async throws -> [(id: String, url: URL)] {
        []
    }
}
