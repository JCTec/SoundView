import Foundation

/// Production song package store.
///
/// - Packages live under `Packages/<uuid>.soundview/` (see `PackageLayout`).
/// - Prefer iCloud ubiquity container Documents so content appears as
///   **SoundView in iCloud Drive**; fall back to local Application Support.
/// - All multi-step writes go through `NSFileCoordinator`.
/// - UI never receives absolute paths — only `SongPackage` + `SyncStatus`.
actor FileStore: FileStoreProtocol {
    /// `FileManager` is used only inside this actor; marked unsafe for Swift 6 Sendable checks.
    nonisolated(unsafe) private let fileManager: FileManager
    private let root: StorageRoot
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    /// Production resolver (iCloud when available).
    init(
        ubiquityContainerIdentifier: String? = "iCloud.com.soundview.app",
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.root = try StorageRootResolver(
            ubiquityContainerIdentifier: ubiquityContainerIdentifier,
            fileManager: fileManager
        ).resolve()
        self.jsonEncoder = Self.makeEncoder()
        self.jsonDecoder = Self.makeDecoder()
    }

    /// Injected root for tests / previews that must not touch iCloud.
    init(testingRoot: URL, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.root = try StorageRootResolver.testing(root: testingRoot, fileManager: fileManager)
        self.jsonEncoder = Self.makeEncoder()
        self.jsonDecoder = Self.makeDecoder()
    }

    // MARK: - FileStoreProtocol

    func listSongs() async throws -> [SongPackage] {
        let packagesDir = root.url.appendingPathComponent(
            PackageLayout.packagesDirectoryName,
            isDirectory: true
        )
        try ensurePackagesDirectory(packagesDir)

        let contents = try fileManager.contentsOfDirectory(
            at: packagesDir,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var pairs: [(manifest: PackageManifest, song: SongPackage)] = []
        pairs.reserveCapacity(contents.count)

        for url in contents {
            // Skip in-progress imports and non-packages.
            // `.importing` folders end with `.soundview.importing` so pathExtension is not `soundview`.
            guard url.pathExtension == PackageLayout.packageExtension else { continue }

            requestUbiquitousDownloadIfNeeded(at: url)

            do {
                let manifest = try readManifest(at: PackageLayout.manifestURL(packageURL: url))
                pairs.append((manifest, songPackage(from: manifest)))
            } catch {
                // Skip corrupt packages rather than failing the whole library.
                continue
            }
        }

        return pairs
            .sorted { lhs, rhs in
                if lhs.manifest.modifiedAt != rhs.manifest.modifiedAt {
                    return lhs.manifest.modifiedAt > rhs.manifest.modifiedAt
                }
                return lhs.song.title.localizedCaseInsensitiveCompare(rhs.song.title) == .orderedAscending
            }
            .map(\.song)
    }

    func song(id: String) async throws -> SongPackage? {
        let packageURL = PackageLayout.packageURL(root: root.url, id: id)
        guard fileManager.fileExists(atPath: packageURL.path) else { return nil }
        requestUbiquitousDownloadIfNeeded(at: packageURL)
        let manifest = try readManifest(at: PackageLayout.manifestURL(packageURL: packageURL))
        return songPackage(from: manifest)
    }

    func importAudio(from url: URL, autoSeparate mode: StemMode) async throws -> SongPackage {
        // Document-picker URLs need security scope; plain file URLs (tests) may return false.
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let metadata: AudioMetadataReader.Metadata
        do {
            metadata = try await AudioMetadataReader.read(from: url)
        } catch {
            if !fileManager.isReadableFile(atPath: url.path) {
                throw FileStoreError.securityScopedAccessDenied
            }
            throw FileStoreError.unreadableAudio(url.lastPathComponent)
        }
        let id = UUID().uuidString
        let title = url.deletingPathExtension().lastPathComponent
        let originalName = PackageLayout.originalFileName(forSourceExtension: url.pathExtension)
        let now = Date()

        let manifest = PackageManifest(
            schemaVersion: PackageManifest.currentSchemaVersion,
            id: id,
            title: title.isEmpty ? "Untitled" : title,
            createdAt: now,
            modifiedAt: now,
            duration: metadata.duration,
            originalFileName: originalName,
            originalFormat: metadata.formatLabel,
            intendedStemMode: mode.rawValue,
            separation: .pending(mode: mode),
            stems: []
        )

        let importingURL = PackageLayout.importingPackageURL(root: root.url, id: id)
        let finalURL = PackageLayout.packageURL(root: root.url, id: id)

        try CoordinatedFileIO.createDirectory(at: importingURL, fileManager: fileManager)
        try CoordinatedFileIO.createDirectory(
            at: PackageLayout.stemsDirectoryURL(packageURL: importingURL),
            fileManager: fileManager
        )

        let destinationOriginal = PackageLayout.originalURL(
            packageURL: importingURL,
            fileName: originalName
        )
        try CoordinatedFileIO.copyItem(from: url, to: destinationOriginal, fileManager: fileManager)
        try writeManifest(manifest, packageURL: importingURL)
        try writeMix(MixStateDocument.empty, packageURL: importingURL)

        // Atomic publish: only complete packages are listed.
        try CoordinatedFileIO.moveItem(from: importingURL, to: finalURL, fileManager: fileManager)
        requestUbiquitousDownloadIfNeeded(at: finalURL)

        return songPackage(from: manifest)
    }

    func deleteSong(id: String) async throws {
        let packageURL = PackageLayout.packageURL(root: root.url, id: id)
        guard fileManager.fileExists(atPath: packageURL.path) else {
            throw FileStoreError.packageNotFound(id)
        }
        try CoordinatedFileIO.removeItem(at: packageURL, fileManager: fileManager)
    }

    func updateSeparation(
        id: String,
        status: SeparationStatus,
        progress: Double,
        stems: [StemFileEntry]?
    ) async throws -> SongPackage {
        let packageURL = PackageLayout.packageURL(root: root.url, id: id)
        guard fileManager.fileExists(atPath: packageURL.path) else {
            throw FileStoreError.packageNotFound(id)
        }
        var manifest = try readManifest(at: PackageLayout.manifestURL(packageURL: packageURL))
        manifest.separation.status = status
        manifest.separation.progress = min(1, max(0, progress))
        if let stems {
            manifest.stems = stems
        }
        if status == .finished {
            manifest.separation.progress = 1
        }
        manifest.modifiedAt = Date()
        try writeManifest(manifest, packageURL: packageURL)
        return songPackage(from: manifest)
    }

    func currentSyncStatus() async -> SyncStatus {
        root.defaultSyncStatus
    }

    func storageDisplaySentence() async -> String {
        root.displaySentence
    }

    /// Absolute URL for internal services only (mixer, separator). Never show in UI.
    func packageDirectoryURL(id: String) async throws -> URL {
        let url = PackageLayout.packageURL(root: root.url, id: id)
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileStoreError.packageNotFound(id)
        }
        return url
    }

    func originalAudioURL(id: String) async throws -> URL {
        let packageURL = try await packageDirectoryURL(id: id)
        let manifest = try readManifest(at: PackageLayout.manifestURL(packageURL: packageURL))
        let audioURL = PackageLayout.originalURL(
            packageURL: packageURL,
            fileName: manifest.originalFileName
        )
        guard fileManager.fileExists(atPath: audioURL.path) else {
            throw FileStoreError.unreadableAudio(manifest.originalFileName)
        }
        return audioURL
    }

    /// Absolute stem WAV URLs in lane order. Internal services only.
    func stemAudioURLs(id: String) async throws -> [(id: String, url: URL)] {
        let packageURL = try await packageDirectoryURL(id: id)
        let manifest = try readManifest(at: PackageLayout.manifestURL(packageURL: packageURL))
        return try manifest.stems
            .sorted { $0.index < $1.index }
            .map { entry in
                let url = PackageLayout.stemURL(packageURL: packageURL, fileName: entry.fileName)
                guard fileManager.fileExists(atPath: url.path) else {
                    throw FileStoreError.unreadableAudio(entry.fileName)
                }
                return (id: entry.id, url: url)
            }
    }

    // MARK: - Private

    private func songPackage(from manifest: PackageManifest) -> SongPackage {
        manifest.toSongPackage(
            relativeDayLabel: RelativeDayLabel.make(for: manifest.modifiedAt)
        )
    }

    private func readManifest(at url: URL) throws -> PackageManifest {
        let data = try CoordinatedFileIO.readData(at: url)
        do {
            let manifest = try jsonDecoder.decode(PackageManifest.self, from: data)
            guard manifest.schemaVersion <= PackageManifest.currentSchemaVersion else {
                throw FileStoreError.invalidManifest("Unsupported schema \(manifest.schemaVersion)")
            }
            return manifest
        } catch let error as FileStoreError {
            throw error
        } catch {
            throw FileStoreError.invalidManifest(error.localizedDescription)
        }
    }

    private func writeManifest(_ manifest: PackageManifest, packageURL: URL) throws {
        let data = try jsonEncoder.encode(manifest)
        try CoordinatedFileIO.writeData(data, to: PackageLayout.manifestURL(packageURL: packageURL))
    }

    private func writeMix(_ mix: MixStateDocument, packageURL: URL) throws {
        let data = try jsonEncoder.encode(mix)
        try CoordinatedFileIO.writeData(data, to: PackageLayout.mixURL(packageURL: packageURL))
    }

    private func ensurePackagesDirectory(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try CoordinatedFileIO.createDirectory(at: url, fileManager: fileManager)
        }
    }

    private func requestUbiquitousDownloadIfNeeded(at url: URL) {
        guard root.kind == .iCloud else { return }
        var values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .isUbiquitousItemKey
            ])
        } catch {
            return
        }
        guard values.isUbiquitousItem == true else { return }
        if values.ubiquitousItemDownloadingStatus == .current { return }
        try? fileManager.startDownloadingUbiquitousItem(at: url)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
