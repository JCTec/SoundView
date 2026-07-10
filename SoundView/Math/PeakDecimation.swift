import Accelerate
import Foundation

/// Min/max peak buckets for waveform drawing.
///
/// See `docs/MATH.md` §2. Uses vDSP on large slices; higher-order helpers on small arrays.
enum PeakDecimation {
    struct Peak: Equatable, Sendable {
        var min: Float
        var max: Float
    }

    /// Decimates mono samples into `bucketCount` min/max peaks.
    static func minMaxPeaks(samples: [Float], bucketCount: Int) -> [Peak] {
        guard bucketCount > 0, !samples.isEmpty else { return [] }

        let count = samples.count
        return (0..<bucketCount).map { bucket in
            let start = bucket * count / bucketCount
            let end = (bucket + 1) * count / bucketCount
            guard start < end else {
                let value = samples[min(start, count - 1)]
                return Peak(min: value, max: value)
            }
            return minMax(samples: samples, start: start, end: end)
        }
    }

    /// Pyramid tier: longer songs use coarser buckets (seconds → peaks).
    static func bucketCount(forDuration duration: TimeInterval, peaksPerSecond: Double = 100) -> Int {
        max(1, Int((duration * peaksPerSecond).rounded(.up)))
    }

    // MARK: - Private

    private static func minMax(samples: [Float], start: Int, end: Int) -> Peak {
        let length = vDSP_Length(end - start)
        var minValue: Float = 0
        var maxValue: Float = 0
        samples.withUnsafeBufferPointer { buffer in
            let base = buffer.baseAddress!.advanced(by: start)
            vDSP_minv(base, 1, &minValue, length)
            vDSP_maxv(base, 1, &maxValue, length)
        }
        return Peak(min: minValue, max: maxValue)
    }
}

extension Array {
    /// Splits into contiguous chunks of `size` (last chunk may be shorter).
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return [] }
        return stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }
}
