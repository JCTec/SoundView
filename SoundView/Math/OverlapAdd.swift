import Foundation

/// Overlap-add reconstruction for chunked model inference.
///
/// See `docs/MATH.md` §4.
enum OverlapAdd {
    /// Accumulates a windowed chunk into `output` / `weights` at `hop` offset.
    static func accumulate(
        chunk: [Float],
        window: [Float],
        hopOffset: Int,
        output: inout [Float],
        weights: inout [Float]
    ) {
        precondition(chunk.count == window.count, "chunk and window length must match")
        let length = chunk.count
        let needed = hopOffset + length
        if output.count < needed {
            output.append(contentsOf: repeatElement(0, count: needed - output.count))
            weights.append(contentsOf: repeatElement(0, count: needed - weights.count))
        }

        for index in 0..<length {
            let destination = hopOffset + index
            let weight = window[index]
            output[destination] += chunk[index] * weight
            weights[destination] += weight
        }
    }

    /// Normalizes accumulated samples by window weight sum.
    static func normalize(output: [Float], weights: [Float], epsilon: Float = 1e-8) -> [Float] {
        zip(output, weights).map { sample, weight in
            sample / max(weight, epsilon)
        }
    }

    /// Hann window of length `n` (periodic form suitable for OLA).
    static func hannWindow(length: Int) -> [Float] {
        guard length > 0 else { return [] }
        if length == 1 { return [1] }
        return (0..<length).map { index in
            let phase = 2 * Float.pi * Float(index) / Float(length)
            return 0.5 * (1 - cosf(phase))
        }
    }
}
