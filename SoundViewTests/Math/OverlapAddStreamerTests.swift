import XCTest
@testable import SoundView

final class OverlapAddStreamerTests: XCTestCase {
    /// The streaming overlap-add must reconstruct exactly what the batch
    /// `OverlapAdd` (accumulate whole song → normalize) produces — same math, just
    /// flushed incrementally. If this holds, separation quality can't regress.
    func testMatchesBatchOverlapAdd() {
        let segment = 16
        let hop = segment * 3 / 4          // 25% overlap, as the backends use
        let channels = 2
        let totalFrames = 40
        let chunkCount = max(1, (totalFrames - 1) / hop + 1)
        let window = OverlapAdd.hannWindow(length: segment)

        // Deterministic pseudo-random chunks: [chunk][channel][segment].
        var seed: UInt64 = 0xC0FFEE
        func next() -> Float {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(seed >> 40) / Float(1 << 24) - 0.5
        }
        let chunks: [[[Float]]] = (0..<chunkCount).map { _ in
            (0..<channels).map { _ in (0..<segment).map { _ in next() } }
        }

        // Batch reference.
        var accumulated = (0..<channels).map { _ in [Float]() }
        var weights = (0..<channels).map { _ in [Float]() }
        for chunk in 0..<chunkCount {
            for channel in 0..<channels {
                OverlapAdd.accumulate(
                    chunk: chunks[chunk][channel], window: window, hopOffset: chunk * hop,
                    output: &accumulated[channel], weights: &weights[channel]
                )
            }
        }
        let reference = (0..<channels).map { channel in
            Array(OverlapAdd.normalize(output: accumulated[channel], weights: weights[channel])
                .prefix(totalFrames))
        }

        // Streaming.
        let streamer = OverlapAddStreamer(segment: segment, channels: channels, window: window)
        var streamed = (0..<channels).map { _ in [Float]() }
        for chunk in 0..<chunkCount {
            let offset = chunk * hop
            let flush = chunk == chunkCount - 1 ? totalFrames - offset : hop
            let flushed = streamer.push(chunks[chunk], flush: flush)
            for channel in 0..<channels {
                streamed[channel].append(contentsOf: flushed[channel])
            }
        }

        for channel in 0..<channels {
            XCTAssertEqual(streamed[channel].count, totalFrames)
            for index in 0..<totalFrames {
                XCTAssertEqual(
                    streamed[channel][index], reference[channel][index], accuracy: 1e-6,
                    "channel \(channel) sample \(index)"
                )
            }
        }
    }
}
