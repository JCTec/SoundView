import Foundation

/// Streams multi-source separation output straight to per-stem WAV files,
/// overlap-adding each chunk on the fly (`OverlapAddStreamer` + `WAVStreamWriter`)
/// so memory stays flat regardless of song length. Used by the Demucs backend.
/// `sources` are stem file keys (e.g. "vocals", "drums").
final class StemAssembly {
    private let sources: [String]
    private let tempRoot: URL
    private let urls: [URL]
    private var streamers: [OverlapAddStreamer]
    private var writers: [WAVStreamWriter]

    init(
        sources: [String], channels: Int, segment: Int, window: [Float], sampleRate: Double
    ) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundView-sep-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURLs = sources.map { root.appendingPathComponent("\($0).wav") }

        self.sources = sources
        tempRoot = root
        urls = fileURLs
        streamers = sources.map { _ in
            OverlapAddStreamer(segment: segment, channels: channels, window: window)
        }
        writers = try fileURLs.map {
            try WAVStreamWriter(url: $0, sampleRate: sampleRate, channels: channels)
        }
    }

    /// `stems`: `[source][channel][segment]`. Emits `flush` finalized samples per
    /// stem to disk (`hop` for interior chunks, `totalFrames − offset` for the last).
    func write(_ stems: [[[Float]]], flush: Int) throws {
        for source in 0..<sources.count {
            let flushed = streamers[source].push(stems[source], flush: flush)
            try writers[source].append(flushed)
        }
    }

    /// Finalizes the WAV files and returns the produced stems.
    func finish() -> [ProducedStem] {
        writers.removeAll()  // AVAudioFile finalizes each file on deinit
        return sources.enumerated().map { index, key in
            ProducedStem(
                id: key,
                name: StemCatalog.displayName(forFileKey: key),
                index: index,
                fileURL: urls[index]
            )
        }
    }
}
