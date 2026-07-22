import Accelerate
import Foundation

/// Demucs-exact spectral transform per the model manifest:
/// periodic Hann 4096, hop 1024, spectra normalized by 1/√n_fft, reflect-pad
/// 1536 then (torch center) reflect-pad 2048, keep centered `frames` frames,
/// drop the Nyquist bin. The inverse mirrors every step, so round-trip is
/// verifiable in `DemucsSpecTests` — and matching our own forward means
/// matching torch's, since the forward math is deterministic.
struct DemucsSpec {
    let nfft: Int
    let hop: Int
    let frames: Int
    let bins: Int          // 2048 — Nyquist dropped per manifest
    let segmentSamples: Int

    private let edgePad: Int      // 1536 = hop/2*3 (Demucs pre-pad)
    private let centerPad: Int    // 2048 = nfft/2 (torch center pad)
    private let window: [Float]
    private let fft: RealFFT       // shared vDSP core (see RealFFT.swift)
    private let scale: Float      // 1/√nfft (normalized STFT)

    /// One channel's spectrum in model layout: plane index `bin * frames + frame`.
    struct ChannelSpectrum {
        var real: [Float]
        var imag: [Float]
    }

    init?(nfft: Int = 4_096, hop: Int = 1_024, frames: Int = 336, segmentSamples: Int = 343_980) {
        guard nfft > 0, nfft & (nfft - 1) == 0 else { return nil }
        self.nfft = nfft
        self.hop = hop
        self.frames = frames
        self.segmentSamples = segmentSamples
        bins = nfft / 2
        edgePad = hop / 2 * 3
        centerPad = nfft / 2
        scale = 1 / sqrt(Float(nfft))
        guard let fft = RealFFT(nfft: nfft) else { return nil }
        self.fft = fft
        // Periodic Hann (torch default): w[k] = 0.5(1 − cos(2πk/N)).
        window = (0..<nfft).map { 0.5 * (1 - cosf(2 * .pi * Float($0) / Float(nfft))) }
    }

    // MARK: - Forward

    func forward(_ samples: [Float]) -> ChannelSpectrum {
        let padded = Self.reflectPadded(samples, by: edgePad + centerPad)
        var real = [Float](repeating: 0, count: bins * frames)
        var imag = [Float](repeating: 0, count: bins * frames)

        var frameBuffer = [Float](repeating: 0, count: nfft)
        var splitReal = [Float](repeating: 0, count: nfft / 2)
        var splitImag = [Float](repeating: 0, count: nfft / 2)

        // torch yields extra frames; the model keeps the centered block [2, 2+frames).
        for outFrame in 0..<frames {
            let torchFrame = outFrame + 2
            let start = torchFrame * hop
            for offset in 0..<nfft {
                let index = start + offset
                frameBuffer[offset] = (index < padded.count ? padded[index] : 0) * window[offset]
            }
            fft.forward(frame: frameBuffer, real: &splitReal, imag: &splitImag)

            // Unpack zrip (÷2) then apply the normalized-STFT scale; drop Nyquist.
            real[outFrame] = splitReal[0] / 2 * scale                 // bin 0 column offset
            imag[outFrame] = 0
            for bin in 1..<bins {
                let planeIndex = bin * frames + outFrame
                real[planeIndex] = splitReal[bin] / 2 * scale
                imag[planeIndex] = splitImag[bin] / 2 * scale
            }
        }
        return ChannelSpectrum(real: real, imag: imag)
    }

    // MARK: - Inverse

    /// Inverts `forward` (manifest post-proc: re-add Nyquist=0, pad 2 frames each
    /// side as zeros, WOLA, undo center + edge pads).
    func inverse(_ spectrum: ChannelSpectrum) -> [Float] {
        let totalFrames = frames + 4                       // 2 zero frames each side
        let paddedLength = (totalFrames - 1) * hop + nfft
        var accumulated = [Float](repeating: 0, count: paddedLength)
        var weights = [Float](repeating: 0, count: paddedLength)

        var splitReal = [Float](repeating: 0, count: nfft / 2)
        var splitImag = [Float](repeating: 0, count: nfft / 2)
        var frameBuffer = [Float](repeating: 0, count: nfft)

        for frame in 0..<totalFrames {
            let sourceFrame = frame - 2
            if sourceFrame >= 0 && sourceFrame < frames {
                // Repack: undo normalization scale, restore zrip packing (×2), Nyquist = 0.
                splitReal[0] = spectrum.real[sourceFrame] / scale * 2
                splitImag[0] = 0
                for bin in 1..<bins {
                    let planeIndex = bin * frames + sourceFrame
                    splitReal[bin] = spectrum.real[planeIndex] / scale * 2
                    splitImag[bin] = spectrum.imag[planeIndex] / scale * 2
                }
            } else {
                for bin in 0..<(nfft / 2) {
                    splitReal[bin] = 0
                    splitImag[bin] = 0
                }
            }
            fft.inverse(real: &splitReal, imag: &splitImag, into: &frameBuffer)

            let start = frame * hop
            for offset in 0..<nfft {
                let index = start + offset
                guard index < paddedLength else { break }
                accumulated[index] += frameBuffer[offset] / (2 * Float(nfft)) * window[offset]
                weights[index] += window[offset] * window[offset]
            }
        }

        // The 2 leading zero frames shift content by 2·hop relative to the pads.
        let contentStart = centerPad + edgePad
        var output = [Float](repeating: 0, count: segmentSamples)
        for index in 0..<segmentSamples {
            let source = contentStart + index
            guard source < paddedLength, weights[source] > 1e-8 else { continue }
            output[index] = accumulated[source] / weights[source]
        }
        return output
    }

    // MARK: - Helpers

    static func reflectPadded(_ samples: [Float], by pad: Int) -> [Float] {
        guard !samples.isEmpty else { return [Float](repeating: 0, count: pad * 2) }
        let count = samples.count
        var out = [Float]()
        out.reserveCapacity(count + 2 * pad)
        for index in stride(from: pad, to: 0, by: -1) {
            out.append(samples[min(index, count - 1)])
        }
        out.append(contentsOf: samples)
        for index in 2...(pad + 1) {
            out.append(samples[max(0, count - index)])
        }
        return out
    }
}
