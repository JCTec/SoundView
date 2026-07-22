import AVFoundation
import Foundation

/// Writes float PCM to a 16-bit WAV **incrementally** as chunks arrive, so a full
/// song's stems never need to be held in memory (pairs with `OverlapAddStreamer`).
/// Same on-disk format as `AudioFileIO.writeWAV`. `AVAudioFile` grows the header
/// on each write and finalizes on deinit.
final class WAVStreamWriter {
    private let file: AVAudioFile
    private let format: AVAudioFormat
    let channels: Int

    init(url: URL, sampleRate: Double, channels: Int) throws {
        self.channels = max(1, channels)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(self.channels),
            interleaved: false
        ) else {
            throw FileStoreError.ioFailed("Could not build audio format for \(url.lastPathComponent)")
        }
        self.format = format

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: self.channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        )
    }

    /// Appends one block, `[channel][frame]`.
    func append(_ channelsData: [[Float]]) throws {
        guard let frames = channelsData.first?.count, frames > 0 else { return }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)
        ) else {
            throw FileStoreError.ioFailed("Could not allocate PCM buffer")
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        guard let channelData = buffer.floatChannelData else {
            throw FileStoreError.ioFailed("Missing channel data")
        }
        for channel in 0..<channels {
            channelsData[channel].withUnsafeBufferPointer { source in
                channelData[channel].update(from: source.baseAddress!, count: frames)
            }
        }
        try file.write(from: buffer)
    }
}
