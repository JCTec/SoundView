import Foundation

/// Output format for exported audio — WAV is the quality default, M4A the
/// smaller option (docs/PRODUCT.md §2.3).
enum StemExportFormat: String, CaseIterable, Identifiable, Sendable {
    case wav
    case m4a

    var id: String { rawValue }
    var title: String { self == .wav ? "WAV" : "M4A" }
    var fileExtension: String { rawValue }
}

/// What to deliver — the "Every stem out" promise.
enum StemExportSelection: Sendable, Equatable {
    case currentMix               // offline render through the mix gains
    case allStems                 // every stem, zipped
    case pickedStems([String])    // chosen stem ids
}

enum StemExportEvent: Sendable {
    case progress(Double)
    case finished(URL)
}

enum StemExportError: Error, LocalizedError, Sendable {
    case noStems
    case nothingSelected

    var errorDescription: String? {
        switch self {
        case .noStems: return "There are no stems to export yet."
        case .nothingSelected: return "Pick at least one stem to export."
        }
    }
}

/// Offline stem export. Renders the current mix (summing stems through their mix
/// gains) or packages stems as WAV/M4A, delivering a single shareable file.
/// Progress + cancellation via `AsyncThrowingStream`, mirroring the separation
/// backends.
struct StemExporter {
    struct Stem: Sendable {
        let id: String
        let name: String
        let url: URL
        /// Effective lane gain for the current-mix render (solo/mute/volume folded in).
        var gain: Float = 1
    }

    let title: String

    func export(
        stems: [StemExporter.Stem],
        selection: StemExportSelection,
        format: StemExportFormat
    ) -> AsyncThrowingStream<StemExportEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                Log.info(.export, "export start", ["format": format.fileExtension, "stems": String(stems.count)])
                do {
                    let url = try self.run(stems: stems, selection: selection, format: format) { progress in
                        continuation.yield(.progress(progress))
                    }
                    Log.info(.export, "export done", ["file": url.lastPathComponent])
                    continuation.yield(.finished(url))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    Log.error(.export, "export failed", ["error": String(describing: error)])
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Work

    private func run(
        stems: [StemExporter.Stem],
        selection: StemExportSelection,
        format: StemExportFormat,
        onProgress: (Double) -> Void
    ) throws -> URL {
        switch selection {
        case .currentMix:
            return try renderMix(stems: stems, format: format, onProgress: onProgress)
        case .allStems:
            return try packageStems(stems, format: format, onProgress: onProgress)
        case .pickedStems(let ids):
            let picked = stems.filter { ids.contains($0.id) }
            guard !picked.isEmpty else { throw StemExportError.nothingSelected }
            return try packageStems(picked, format: format, onProgress: onProgress)
        }
    }

    private func renderMix(
        stems: [StemExporter.Stem], format: StemExportFormat, onProgress: (Double) -> Void
    ) throws -> URL {
        guard !stems.isEmpty else { throw StemExportError.noStems }
        var mix: [Float] = []
        var sampleRate: Double = 44_100
        var channels = 2
        for (index, stem) in stems.enumerated() {
            try Task.checkCancellation()
            let pcm = try AudioFileIO.loadPCM(from: stem.url)
            sampleRate = pcm.sampleRate
            channels = pcm.channelCount
            if mix.count < pcm.interleaved.count {
                mix.append(contentsOf: repeatElement(0, count: pcm.interleaved.count - mix.count))
            }
            for index in 0..<pcm.interleaved.count {
                mix[index] += pcm.interleaved[index] * stem.gain
            }
            onProgress(0.1 + 0.7 * Double(index + 1) / Double(stems.count))
        }
        let buffer = AudioFileIO.PCMBuffer(sampleRate: sampleRate, channelCount: channels, interleaved: mix)
        let url = try write(buffer, name: "\(safeTitle) (mix)", format: format)
        onProgress(1)
        return url
    }

    private func packageStems(
        _ stems: [StemExporter.Stem], format: StemExportFormat, onProgress: (Double) -> Void
    ) throws -> URL {
        guard !stems.isEmpty else { throw StemExportError.noStems }
        if stems.count == 1 {
            let url = try placeStem(stems[0], name: "\(safeTitle) - \(Self.safeName(stems[0].name))", format: format)
            onProgress(1)
            return url
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeTitle) stems", isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (index, stem) in stems.enumerated() {
            try Task.checkCancellation()
            let name = "\(String(format: "%02d", index))-\(Self.safeName(stem.name))"
            let fileURL = directory.appendingPathComponent("\(name).\(format.fileExtension)")
            try encode(stem, to: fileURL, format: format)
            onProgress(0.1 + 0.7 * Double(index + 1) / Double(stems.count))
        }
        let zipURL = try AudioFileIO.zip(directory: directory, archiveName: "\(safeTitle) stems.zip")
        onProgress(1)
        return zipURL
    }

    // MARK: - File helpers

    /// Encodes one stem into its own freshly-named temp file.
    private func placeStem(_ stem: StemExporter.Stem, name: String, format: StemExportFormat) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundView-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).\(format.fileExtension)")
        try encode(stem, to: url, format: format)
        return url
    }

    /// WAV stems on disk are copied byte-for-byte; M4A is transcoded via AAC.
    private func encode(_ stem: StemExporter.Stem, to url: URL, format: StemExportFormat) throws {
        switch format {
        case .wav:
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.copyItem(at: stem.url, to: url)
        case .m4a:
            try AudioFileIO.writeM4A(pcm: AudioFileIO.loadPCM(from: stem.url), to: url)
        }
    }

    private func write(_ pcm: AudioFileIO.PCMBuffer, name: String, format: StemExportFormat) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundView-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).\(format.fileExtension)")
        switch format {
        case .wav: try AudioFileIO.writeWAV(pcm: pcm, to: url)
        case .m4a: try AudioFileIO.writeM4A(pcm: pcm, to: url)
        }
        return url
    }

    private var safeTitle: String { Self.safeName(title.isEmpty ? "SoundView" : title) }

    static func safeName(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines)
        let cleaned = raw.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "SoundView" : cleaned
    }
}
