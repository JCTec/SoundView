import Foundation

/// Orchestrates stem separation into a package’s `stems/` folder via
/// `ModelCatalog` (single studio engine: Meta Demucs). Pipeline (progress, energy tags,
/// FileStore writes) is real.
final class StemSeparator: StemSeparating, @unchecked Sendable {
    private let fileStore: any FileStoreProtocol
    private let catalog: any ModelCataloging
    /// Test/preview override — when set, every run uses this backend regardless
    /// of the selected quality.
    private let backendOverride: (any StemSeparationBackend)?

    init(
        fileStore: any FileStoreProtocol,
        catalog: any ModelCataloging = ModelCatalog(),
        backend: (any StemSeparationBackend)? = nil
    ) {
        self.fileStore = fileStore
        self.catalog = catalog
        backendOverride = backend
    }

    func separate(
        packageID: String,
        mode: StemMode,
        quality: SeparationQuality
    ) -> AsyncThrowingStream<StemEvent, Error> {
        let backend = backendOverride ?? catalog.backend(for: quality)
        Log.info(.separation, "route", [
            "quality": quality.rawValue,
            "mode": mode.rawValue,
            "backend": backend.map { String(describing: type(of: $0)) } ?? "unavailable"
        ])
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let backend else {
                        throw StemSeparatorError.modelUnavailable(
                            "The studio model isn’t ready in this build yet."
                        )
                    }
                    try await self.runSeparation(
                        packageID: packageID,
                        mode: mode,
                        backend: backend,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runSeparation(
        packageID: String,
        mode: StemMode,
        backend: any StemSeparationBackend,
        continuation: AsyncThrowingStream<StemEvent, Error>.Continuation
    ) async throws {
        guard let package = try await fileStore.song(id: packageID) else {
            throw FileStoreError.packageNotFound(packageID)
        }

        try await markRunning(packageID: packageID, progress: 0.02)
        continuation.yield(.progress(0.02, eta: nil))

        let originalURL = try await fileStore.originalAudioURL(id: packageID)
        let packageURL = try await fileStore.packageDirectoryURL(id: packageID)
        let stemsDir = PackageLayout.stemsDirectoryURL(packageURL: packageURL)
        try CoordinatedFileIO.createDirectory(at: stemsDir)

        let produced = try await collectBackendStems(
            originalURL: originalURL,
            package: package,
            mode: mode,
            backend: backend,
            continuation: continuation
        )

        let entries = try await writeStemFiles(
            produced: produced,
            stemsDir: stemsDir,
            continuation: continuation
        )

        let finished = try await fileStore.updateSeparation(
            id: packageID,
            status: .finished,
            progress: 1,
            stems: entries
        )
        continuation.yield(.finished(finished.stems))
        continuation.yield(.progress(1, eta: 0))
        notifyPackageChanged(packageID)
    }

    private func collectBackendStems(
        originalURL: URL,
        package: SongPackage,
        mode: StemMode,
        backend: any StemSeparationBackend,
        continuation: AsyncThrowingStream<StemEvent, Error>.Continuation
    ) async throws -> [ProducedStem] {
        var produced: [ProducedStem] = []
        for try await event in backend.separate(
            originalURL: originalURL,
            title: package.title,
            duration: package.duration,
            mode: mode
        ) {
            try Task.checkCancellation()
            switch event {
            case .progress(let value, let eta):
                continuation.yield(.progress(value, eta: eta))
                try await markRunning(packageID: package.id, progress: value)
            case .stem(let stem):
                produced.append(stem)
                continuation.yield(
                    .found(
                        StemDescriptor(
                            id: stem.id,
                            name: stem.name,
                            index: stem.index,
                            isLowEnergy: false
                        )
                    )
                )
            }
        }
        return produced
    }

    private func writeStemFiles(
        produced: [ProducedStem],
        stemsDir: URL,
        continuation: AsyncThrowingStream<StemEvent, Error>.Continuation
    ) async throws -> [StemFileEntry] {
        var entries: [StemFileEntry] = []
        let total = max(produced.count, 1)
        let started = Date()
        for (offset, stem) in produced.enumerated() {
            try Task.checkCancellation()
            let resolvedName = StemCatalog.stemFileName(index: stem.index, displayName: stem.name)
            let dest = stemsDir.appendingPathComponent(resolvedName)
            try CoordinatedFileIO.copyItem(from: stem.fileURL, to: dest)

            let pcm = try AudioFileIO.loadPCM(from: dest)
            let energy = StemEnergy.analyze(samples: AudioFileIO.monoMid(from: pcm))
            entries.append(
                StemFileEntry(
                    id: stem.id,
                    name: stem.name,
                    index: stem.index,
                    fileName: resolvedName,
                    isLowEnergy: energy.isLowEnergy
                )
            )

            let progress = 0.85 + 0.14 * Double(offset + 1) / Double(total)
            let eta = max(0, 2 - Date().timeIntervalSince(started))
            continuation.yield(.progress(progress, eta: eta))
        }
        return entries
    }

    private func markRunning(packageID: String, progress: Double) async throws {
        _ = try await fileStore.updateSeparation(
            id: packageID,
            status: .running,
            progress: progress,
            stems: nil
        )
    }

    private func notifyPackageChanged(_ packageID: String) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .soundViewPackageDidChange,
                object: nil,
                userInfo: ["id": packageID]
            )
        }
    }
}

// MARK: - Backend protocol

protocol StemSeparationBackend: Sendable {
    func separate(
        originalURL: URL,
        title: String,
        duration: TimeInterval,
        mode: StemMode
    ) -> AsyncThrowingStream<BackendStemEvent, Error>
}

enum BackendStemEvent: Sendable {
    case progress(Double, eta: TimeInterval?)
    case stem(ProducedStem)
}

struct ProducedStem: Sendable {
    var id: String
    var name: String
    var index: Int
    /// Temporary or bundle URL of the stem audio to copy into the package.
    var fileURL: URL
}
