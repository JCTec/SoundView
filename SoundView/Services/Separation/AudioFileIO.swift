import AVFoundation
import Foundation

/// Decode / encode helpers for package audio (WAV stems + mix sources).
enum AudioFileIO {
    struct PCMBuffer: Sendable {
        var sampleRate: Double
        var channelCount: Int
        /// Interleaved float samples: frame-major [L,R,L,R,…] or mono [m,m,…].
        var interleaved: [Float]
        var frameCount: Int {
            guard channelCount > 0 else { return 0 }
            return interleaved.count / channelCount
        }
    }

    /// Loads audio into interleaved float PCM (mix-down stays multi-channel).
    static func loadPCM(from url: URL) throws -> PCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw FileStoreError.unreadableAudio(url.lastPathComponent)
        }
        try file.read(into: buffer)
        let channels = Int(format.channelCount)
        let frames = Int(buffer.frameLength)
        guard let channelData = buffer.floatChannelData else {
            throw FileStoreError.unreadableAudio(url.lastPathComponent)
        }

        var interleaved = [Float](repeating: 0, count: frames * channels)
        for frame in 0..<frames {
            for channel in 0..<channels {
                interleaved[frame * channels + channel] = channelData[channel][frame]
            }
        }
        return PCMBuffer(
            sampleRate: format.sampleRate,
            channelCount: channels,
            interleaved: interleaved
        )
    }

    /// Mono mid mix for peak waveforms.
    static func monoMid(from pcm: PCMBuffer) -> [Float] {
        let channels = pcm.channelCount
        guard channels > 0 else { return [] }
        if channels == 1 { return pcm.interleaved }
        let frames = pcm.frameCount
        var mono = [Float](repeating: 0, count: frames)
        let inv = 1 / Float(channels)
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels {
                sum += pcm.interleaved[frame * channels + channel]
            }
            mono[frame] = sum * inv
        }
        return mono
    }

    /// Writes stereo (or mono) interleaved float PCM as 16-bit PCM WAV.
    static func writeWAV(pcm: PCMBuffer, to url: URL) throws {
        let channels = max(1, pcm.channelCount)
        let sampleRate = pcm.sampleRate
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else {
            throw FileStoreError.ioFailed("Could not build audio format for \(url.lastPathComponent)")
        }

        let frames = pcm.frameCount
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else {
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
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        )
        try file.write(from: buffer)
    }

    /// Sums multiple PCM buffers (same length / rate / channels) into one.
    static func sum(_ buffers: [PCMBuffer]) throws -> PCMBuffer {
        guard let first = buffers.first else {
            throw FileStoreError.ioFailed("No buffers to sum")
        }
        var out = first.interleaved
        for buffer in buffers.dropFirst() {
            guard buffer.sampleRate == first.sampleRate,
                  buffer.channelCount == first.channelCount,
                  buffer.interleaved.count == first.interleaved.count else {
                throw FileStoreError.ioFailed("Stem buffers must match format to sum")
            }
            for index in out.indices {
                out[index] += buffer.interleaved[index]
            }
        }
        return PCMBuffer(
            sampleRate: first.sampleRate,
            channelCount: first.channelCount,
            interleaved: out
        )
    }
}
