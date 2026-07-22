import AVFoundation
import Foundation

/// Encoding + packaging helpers for the export pipeline (WAV via the base
/// `AudioFileIO`, M4A/AAC here, plus dependency-free zip via `NSFileCoordinator`).
extension AudioFileIO {
    /// Writes interleaved float PCM as AAC in an `.m4a` container (smaller files;
    /// WAV stays the quality default per docs/PRODUCT.md).
    static func writeM4A(pcm: PCMBuffer, to url: URL) throws {
        let channels = max(1, pcm.channelCount)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: pcm.sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else {
            throw FileStoreError.ioFailed("Could not build audio format for \(url.lastPathComponent)")
        }

        let frames = pcm.frameCount
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(max(frames, 1))
        ) else {
            throw FileStoreError.ioFailed("Could not allocate PCM buffer")
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        guard let channelData = buffer.floatChannelData else {
            throw FileStoreError.ioFailed("Missing channel data")
        }
        for frame in 0..<frames {
            for channel in 0..<channels {
                channelData[channel][frame] = pcm.interleaved[frame * channels + channel]
            }
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: pcm.sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )
        try file.write(from: buffer)
    }

    /// Zips a directory into a single `.zip` at a temporary URL — no third-party
    /// dependency, via `NSFileCoordinator`'s `.forUploading` reading intent
    /// (which packages a directory into a zip archive).
    static func zip(directory: URL, archiveName: String) throws -> URL {
        var coordinatorError: NSError?
        var copyError: Error?
        var result: URL?

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(archiveName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        NSFileCoordinator().coordinate(
            readingItemAt: directory, options: [.forUploading], error: &coordinatorError
        ) { zippedURL in
            // The zipped copy is temporary and removed when the block returns —
            // move it to our own temp URL before that happens.
            do {
                try FileManager.default.copyItem(at: zippedURL, to: destination)
                result = destination
            } catch {
                copyError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
        guard let result else {
            throw FileStoreError.ioFailed("Could not package the stems into a zip.")
        }
        return result
    }
}
