import AVFoundation
import Foundation

/// Lightweight audio probe used at import — duration + format label.
enum AudioMetadataReader {
    struct Metadata: Sendable, Equatable {
        var duration: TimeInterval
        var formatLabel: String
        var sampleRate: Double?
        var channelCount: Int?
    }

    /// Reads duration for formats AVFoundation understands (WAV, M4A, MP3, …).
    static func read(from url: URL) async throws -> Metadata {
        let ext = url.pathExtension.uppercased()
        let formatLabel = ext.isEmpty ? "AUDIO" : ext

        // Prefer AVAudioFile for PCM / simple container formats (fast path).
        if let fileMetadata = try? readWithAudioFile(url: url, formatLabel: formatLabel) {
            return fileMetadata
        }

        let asset = AVURLAsset(url: url)
        let cmDuration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(cmDuration)
        guard seconds.isFinite, seconds >= 0 else {
            throw FileStoreError.unreadableAudio(url.lastPathComponent)
        }

        return Metadata(
            duration: seconds,
            formatLabel: formatLabel,
            sampleRate: nil,
            channelCount: nil
        )
    }

    private static func readWithAudioFile(url: URL, formatLabel: String) throws -> Metadata {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let duration = Double(file.length) / format.sampleRate
        return Metadata(
            duration: duration,
            formatLabel: formatLabel,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount)
        )
    }
}
