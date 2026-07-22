import Foundation

/// Produces real stems from the bundled Demucs `htdemucs_6s` pack for Idilio.
///
/// For other titles, throws — until Core ML HTDemucs is bundled. This keeps the
/// separation pipeline honest: either real audio stems or a clear error.
struct ReferenceDemucsBackend: StemSeparationBackend {
    func separate(
        originalURL: URL,
        title: String,
        duration: TimeInterval,
        mode: StemMode
    ) -> AsyncThrowingStream<BackendStemEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.run(
                        title: title,
                        duration: duration,
                        mode: mode,
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

    private static func run(
        title: String,
        duration: TimeInterval,
        mode: StemMode,
        continuation: AsyncThrowingStream<BackendStemEvent, Error>.Continuation
    ) async throws {
        try validateIdilio(title: title, duration: duration)
        continuation.yield(.progress(0.05, eta: 8))

        let six = try await loadSixStemURLs(continuation: continuation)
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundView-sep-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let workURLs = try await resolveWorkURLs(mode: mode, six: six, tempRoot: tempRoot)
        continuation.yield(.progress(0.7, eta: 2))
        try yieldStems(workURLs, continuation: continuation)
    }

    private static func validateIdilio(title: String, duration: TimeInterval) throws {
        guard ReferenceStemBank.matchesIdilio(title: title, duration: duration) else {
            throw StemSeparatorError.modelUnavailable(
                "On-device Core ML model not bundled yet. Development track “Idilio” uses precomputed Demucs stems."
            )
        }
        guard ReferenceStemBank.isIdilioPackAvailable else {
            throw StemSeparatorError.missingReferencePack
        }
    }

    private static func loadSixStemURLs(
        continuation: AsyncThrowingStream<BackendStemEvent, Error>.Continuation
    ) async throws -> [String: URL] {
        var six: [String: URL] = [:]
        for (index, key) in ReferenceStemBank.sixKeys.enumerated() {
            guard let url = ReferenceStemBank.stemURL(
                folder: ReferenceStemBank.idilioFolder,
                key: key
            ) else {
                throw StemSeparatorError.missingReferencePack
            }
            six[key] = url
            let fraction = 0.05 + 0.45 * Double(index + 1) / Double(ReferenceStemBank.sixKeys.count)
            continuation.yield(.progress(fraction, eta: 6 - Double(index)))
            await Task.yield()
        }
        return six
    }

    private static func resolveWorkURLs(
        mode: StemMode,
        six: [String: URL],
        tempRoot: URL
    ) async throws -> [(key: String, url: URL)] {
        switch mode {
        case .six, .max:
            return StemCatalog.reduceSixStemKeys(for: mode).compactMap { key in
                guard let url = six[key] else { return nil }
                return (key, url)
            }
        case .four:
            let other = try await summedStem(
                keys: ["other", "guitar", "piano"],
                sources: six,
                to: tempRoot.appendingPathComponent("other-combined.wav")
            )
            return [
                ("vocals", six["vocals"]!),
                ("drums", six["drums"]!),
                ("bass", six["bass"]!),
                ("other", other)
            ]
        case .two:
            let accompaniment = try await summedStem(
                keys: ["drums", "bass", "guitar", "piano", "other"],
                sources: six,
                to: tempRoot.appendingPathComponent("accompaniment.wav")
            )
            return [
                ("vocals", six["vocals"]!),
                ("accompaniment", accompaniment)
            ]
        }
    }

    private static func yieldStems(
        _ workURLs: [(key: String, url: URL)],
        continuation: AsyncThrowingStream<BackendStemEvent, Error>.Continuation
    ) throws {
        for (index, pair) in workURLs.enumerated() {
            try Task.checkCancellation()
            continuation.yield(
                .stem(
                    ProducedStem(
                        id: pair.key,
                        name: StemCatalog.displayName(forFileKey: pair.key),
                        index: index,
                        fileURL: pair.url
                    )
                )
            )
            let progress = 0.7 + 0.25 * Double(index + 1) / Double(workURLs.count)
            continuation.yield(.progress(progress, eta: 1))
        }
    }

    private static func summedStem(
        keys: [String],
        sources: [String: URL],
        to destination: URL
    ) async throws -> URL {
        var buffers: [AudioFileIO.PCMBuffer] = []
        for key in keys {
            guard let url = sources[key] else { continue }
            buffers.append(try AudioFileIO.loadPCM(from: url))
            await Task.yield()
        }
        let summed = try AudioFileIO.sum(buffers)
        try AudioFileIO.writeWAV(pcm: summed, to: destination)
        return destination
    }
}

enum StemSeparatorError: Error, LocalizedError, Sendable {
    case modelUnavailable(String)
    case missingReferencePack

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let message):
            return message
        case .missingReferencePack:
            return "Bundled Idilio Demucs stems are missing from the app. Run scripts/separate_idilio.sh."
        }
    }
}
