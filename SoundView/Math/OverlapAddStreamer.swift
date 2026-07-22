import Foundation

/// Streaming overlap-add. Accumulates windowed chunks like `OverlapAdd`, but
/// **flushes the settled prefix after every push** and keeps only ~one segment in
/// memory — so a full song's stems never sit in RAM (fixes the OOM on long songs).
///
/// Safe because, with 25%-overlap chunks (hop = ¾·segment), every output sample is
/// touched by at most two chunks: once we've added chunk *k*, everything before the
/// next chunk's start is final and can be normalized, emitted, and dropped. The
/// per-sample math is identical to `OverlapAdd` (verified in `OverlapAddStreamerTests`).
final class OverlapAddStreamer {
    private let segment: Int
    private let channels: Int
    private let window: [Float]
    private let epsilon: Float
    private var acc: [[Float]]      // [channel] length `segment`, head at index 0
    private var wsum: [[Float]]

    init(segment: Int, channels: Int, window: [Float], epsilon: Float = 1e-8) {
        precondition(window.count == segment, "window length must equal segment")
        self.segment = segment
        self.channels = channels
        self.window = window
        self.epsilon = epsilon
        acc = Array(repeating: [Float](repeating: 0, count: segment), count: channels)
        wsum = Array(repeating: [Float](repeating: 0, count: segment), count: channels)
    }

    /// Overlap-adds `chunk` (`[channel][segment]`) at the head, then returns the
    /// next `flush` finalized samples per channel and advances the head by `flush`.
    /// Pass `flush == hop` for interior chunks and `totalFrames − offset` for the last.
    func push(_ chunk: [[Float]], flush: Int) -> [[Float]] {
        let flushCount = max(0, min(flush, segment))
        var out = Array(repeating: [Float](repeating: 0, count: flushCount), count: channels)

        for channel in 0..<channels {
            out[channel].withUnsafeMutableBufferPointer { result in
                chunk[channel].withUnsafeBufferPointer { source in
                    window.withUnsafeBufferPointer { win in
                        acc[channel].withUnsafeMutableBufferPointer { accBuf in
                            wsum[channel].withUnsafeMutableBufferPointer { wsumBuf in
                                for index in 0..<segment {
                                    accBuf[index] += source[index] * win[index]
                                    wsumBuf[index] += win[index]
                                }
                                for index in 0..<flushCount {
                                    result[index] = accBuf[index] / max(wsumBuf[index], epsilon)
                                }
                                // Slide the head forward by `flushCount`: keep the
                                // overlap tail, zero the vacated region.
                                let kept = segment - flushCount
                                for index in 0..<kept {
                                    accBuf[index] = accBuf[index + flushCount]
                                    wsumBuf[index] = wsumBuf[index + flushCount]
                                }
                                for index in kept..<segment {
                                    accBuf[index] = 0
                                    wsumBuf[index] = 0
                                }
                            }
                        }
                    }
                }
            }
        }
        return out
    }
}
