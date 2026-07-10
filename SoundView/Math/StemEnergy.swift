import Accelerate
import Foundation

/// Energy metrics for stem quality tags (not silent deletion).
///
/// See `docs/MATH.md` §5.
enum StemEnergy {
    struct Metrics: Equatable, Sendable {
        var rms: Float
        var peak: Float
        /// Relative to loudest stem in the set, 0…1.
        var relative: Float
        var isLowEnergy: Bool
    }

    static func rms(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var value: Float = 0
        vDSP_rmsqv(samples, 1, &value, vDSP_Length(samples.count))
        return value
    }

    static func peakMagnitude(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var value: Float = 0
        vDSP_maxmgv(samples, 1, &value, vDSP_Length(samples.count))
        return value
    }

    /// Scores each stem; tags low energy when relative RMS &lt; `threshold`.
    static func score(
        stems: [[Float]],
        lowEnergyThreshold: Float = 0.05
    ) -> [Metrics] {
        let rmsValues = stems.map(rms)
        let peaks = stems.map(peakMagnitude)
        let loudest = rmsValues.max() ?? 0

        return zip(rmsValues, peaks).map { rmsValue, peak in
            let relative = loudest > 0 ? rmsValue / loudest : 0
            return Metrics(
                rms: rmsValue,
                peak: peak,
                relative: relative,
                isLowEnergy: relative < lowEnergyThreshold
            )
        }
    }
}
