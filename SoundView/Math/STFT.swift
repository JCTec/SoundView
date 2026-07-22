import Accelerate
import Foundation

/// vDSP STFT / iSTFT matching Demucs conventions: n_fft 4096, hop n_fft/4,
/// Hann analysis + synthesis windows, WOLA reconstruction with explicit
/// window-sum normalization (exact at the edges, no COLA assumption).
///
/// See `docs/COREML_SPIKE.md` — the Core ML backend computes the spectral
/// branch here; complex values travel as (real, imag) planes ("cac").
struct STFT {
    let nfft: Int
    let hop: Int
    /// Bins per frame: nfft/2 + 1 (DC…Nyquist).
    var binCount: Int { nfft / 2 + 1 }

    private let window: [Float]
    private let setup: FFTSetup
    private let log2n: vDSP_Length

    struct Spectrum {
        var frameCount: Int
        var binCount: Int
        /// Row-major [frame][bin] planes.
        var real: [Float]
        var imag: [Float]
    }

    init?(nfft: Int = 4_096, hop: Int? = nil) {
        guard nfft > 0, nfft & (nfft - 1) == 0 else { return nil }
        self.nfft = nfft
        self.hop = hop ?? nfft / 4
        log2n = vDSP_Length(log2(Float(nfft)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        self.setup = setup
        var hann = [Float](repeating: 0, count: nfft)
        vDSP_hann_window(&hann, vDSP_Length(nfft), Int32(vDSP_HANN_DENORM))
        window = hann
    }

    // MARK: - Forward

    func forward(_ samples: [Float]) -> Spectrum {
        let frameCount = samples.isEmpty ? 0 : (samples.count + hop - 1) / hop
        var real = [Float](repeating: 0, count: frameCount * binCount)
        var imag = [Float](repeating: 0, count: frameCount * binCount)

        var frame = [Float](repeating: 0, count: nfft)
        var splitReal = [Float](repeating: 0, count: nfft / 2)
        var splitImag = [Float](repeating: 0, count: nfft / 2)

        for frameIndex in 0..<frameCount {
            let start = frameIndex * hop
            for offset in 0..<nfft {
                let sample = start + offset
                frame[offset] = sample < samples.count ? samples[sample] * window[offset] : 0
            }
            forwardTransform(frame: frame, real: &splitReal, imag: &splitImag)

            let base = frameIndex * binCount
            // Unpack zrip: element 0 holds DC (real) and Nyquist (imag).
            real[base] = splitReal[0] / 2
            imag[base] = 0
            real[base + nfft / 2] = splitImag[0] / 2
            imag[base + nfft / 2] = 0
            for bin in 1..<(nfft / 2) {
                real[base + bin] = splitReal[bin] / 2
                imag[base + bin] = splitImag[bin] / 2
            }
        }
        return Spectrum(frameCount: frameCount, binCount: binCount, real: real, imag: imag)
    }

    // MARK: - Inverse

    func inverse(_ spectrum: Spectrum, sampleCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: sampleCount)
        var windowSum = [Float](repeating: 0, count: sampleCount)

        var splitReal = [Float](repeating: 0, count: nfft / 2)
        var splitImag = [Float](repeating: 0, count: nfft / 2)
        var frame = [Float](repeating: 0, count: nfft)

        for frameIndex in 0..<spectrum.frameCount {
            let base = frameIndex * spectrum.binCount
            // Repack into zrip layout (×2 undoes the forward unpack scaling).
            splitReal[0] = spectrum.real[base] * 2
            splitImag[0] = spectrum.real[base + nfft / 2] * 2
            for bin in 1..<(nfft / 2) {
                splitReal[bin] = spectrum.real[base + bin] * 2
                splitImag[bin] = spectrum.imag[base + bin] * 2
            }
            inverseTransform(real: &splitReal, imag: &splitImag, into: &frame)

            let start = frameIndex * hop
            for offset in 0..<nfft {
                let sample = start + offset
                guard sample < sampleCount else { break }
                // vDSP inverse leaves a 2N scale; fold it in with the synthesis window.
                output[sample] += frame[offset] / (2 * Float(nfft)) * window[offset]
                windowSum[sample] += window[offset] * window[offset]
            }
        }

        for index in 0..<sampleCount where windowSum[index] > 1e-8 {
            output[index] /= windowSum[index]
        }
        return output
    }

    // MARK: - Private

    private func forwardTransform(frame: [Float], real: inout [Float], imag: inout [Float]) {
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(
                    realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!
                )
                frame.withUnsafeBufferPointer { framePointer in
                    framePointer.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self, capacity: nfft / 2
                    ) { complexPointer in
                        vDSP_ctoz(complexPointer, 2, &split, 1, vDSP_Length(nfft / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }
    }

    private func inverseTransform(real: inout [Float], imag: inout [Float], into frame: inout [Float]) {
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(
                    realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!
                )
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
                frame.withUnsafeMutableBufferPointer { framePointer in
                    framePointer.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self, capacity: nfft / 2
                    ) { complexPointer in
                        vDSP_ztoc(&split, 1, complexPointer, 2, vDSP_Length(nfft / 2))
                    }
                }
            }
        }
    }
}
