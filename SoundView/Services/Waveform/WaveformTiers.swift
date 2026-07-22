import Foundation

/// Multi-resolution peak pyramid for one stem — one PCM read, three decimations.
/// `SVWaveformCanvas` picks a tier per zoom via `PeakTierMath`.
struct WaveformTiers: Sendable, Equatable {
    /// bucketCount → peaks, coarse to fine.
    var tiers: [Int: [PeakDecimation.Peak]]
    var duration: TimeInterval

    static let empty = WaveformTiers(tiers: [:], duration: 0)

    var isEmpty: Bool { tiers.isEmpty }

    /// Tiers scale with duration (peaks **per second**), so a long song gets the
    /// same zoomed-in fidelity as a short one. 1000 pps ≈ 1ms buckets — sharp at
    /// the 2s max-zoom window on any screen width.
    static let peaksPerSecondTiers: [Double] = [10, 100, 1_000]

    static func load(
        from url: URL,
        peaksPerSecondTiers tierRates: [Double] = WaveformTiers.peaksPerSecondTiers
    ) throws -> WaveformTiers {
        let pcm = try AudioFileIO.loadPCM(from: url)
        let mono = AudioFileIO.monoMid(from: pcm)
        let duration = Double(pcm.frameCount) / max(pcm.sampleRate, 1)
        var tiers: [Int: [PeakDecimation.Peak]] = [:]
        for rate in tierRates {
            let count = PeakDecimation.bucketCount(forDuration: duration, peaksPerSecond: rate)
            tiers[count] = PeakDecimation.minMaxPeaks(samples: mono, bucketCount: count)
        }
        return WaveformTiers(tiers: tiers, duration: duration)
    }

    /// Disk-cached load: decoding a whole stem is the slow path, so opens after the
    /// first read straight from Caches (`WaveformTierCache`).
    static func loadCached(from url: URL) throws -> WaveformTiers {
        if let cached = WaveformTierCache.load(for: url), !cached.isEmpty {
            return cached
        }
        let computed = try load(from: url)
        WaveformTierCache.store(computed, for: url)
        return computed
    }

    /// Peaks for the tier best matching `required` buckets (see `PeakTierMath`).
    func peaks(required: Int) -> [PeakDecimation.Peak] {
        guard let tier = PeakTierMath.bestTier(available: Array(tiers.keys), required: required) else {
            return []
        }
        return tiers[tier] ?? []
    }
}
