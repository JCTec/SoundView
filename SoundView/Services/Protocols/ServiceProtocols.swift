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
}

/// On-device stem separation.
protocol StemSeparating: Sendable {
    func separate(
        packageID: String,
        mode: StemMode
    ) -> AsyncThrowingStream<StemEvent, Error>
}

enum StemEvent: Sendable {
    case progress(Double, eta: TimeInterval?)
    case found(StemDescriptor)
    case finished([StemDescriptor])
}

/// Multi-lane playback mixer.
protocol StemMixing: Sendable {
    func load(package: SongPackage) async throws
    func setPlaying(_ playing: Bool) async
    func seek(to time: TimeInterval) async
    func setGains(_ gains: [Float]) async
}

// MARK: - Preview / mock

/// Preview store for DesignSystem-first development and SwiftUI previews.
struct PreviewFileStore: FileStoreProtocol {
    var songs: [SongPackage]
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
        return package
    }

    func deleteSong(id: String) async throws {
        // Previews are immutable samples.
    }

    func currentSyncStatus() async -> SyncStatus {
        syncStatus
    }

    func storageDisplaySentence() async -> String {
        storageSentence
    }
}
