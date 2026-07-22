import AVFoundation
import Foundation

extension AudioFileIO {
    /// Decodes any input to the model's canonical format: 44.1 kHz stereo float
    /// (manifest preprocessing steps 1–3: decode, resample, mono→stereo).
    static func loadPCMCanonical(
        from url: URL,
        sampleRate: Double = 44_100,
        channels: AVAudioChannelCount = 2
    ) throws -> PCMBuffer {
        let file = try AVAudioFile(forReading: url)
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            throw FileStoreError.unreadableAudio(url.lastPathComponent)
        }

        if file.processingFormat.sampleRate == sampleRate,
           file.processingFormat.channelCount == channels {
            return try loadPCM(from: url)
        }

        guard let converter = AVAudioConverter(from: file.processingFormat, to: target) else {
            throw FileStoreError.unreadableAudio(url.lastPathComponent)
        }

        let ratio = sampleRate / file.processingFormat.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(file.length) * ratio) + 4_096
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: estimatedFrames),
              let chunk = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: 65_536
              ) else {
            throw FileStoreError.ioFailed("Could not allocate conversion buffers")
        }

        var readerDone = false
        var conversionError: NSError?
        while true {
            let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
                if readerDone {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                do {
                    chunk.frameLength = 0
                    try file.read(into: chunk)
                } catch {
                    readerDone = true
                    outStatus.pointee = .endOfStream
                    return nil
                }
                if chunk.frameLength == 0 {
                    readerDone = true
                    outStatus.pointee = .endOfStream
                    return nil
                }
                outStatus.pointee = .haveData
                return chunk
            }
            if status == .endOfStream || status == .error || output.frameLength >= estimatedFrames {
                break
            }
        }
        if let conversionError {
            throw FileStoreError.ioFailed(conversionError.localizedDescription)
        }

        let frames = Int(output.frameLength)
        guard let channelData = output.floatChannelData else {
            throw FileStoreError.unreadableAudio(url.lastPathComponent)
        }
        var interleaved = [Float](repeating: 0, count: frames * Int(channels))
        for frame in 0..<frames {
            for channel in 0..<Int(channels) {
                interleaved[frame * Int(channels) + channel] = channelData[channel][frame]
            }
        }
        return PCMBuffer(sampleRate: sampleRate, channelCount: Int(channels), interleaved: interleaved)
    }
}
