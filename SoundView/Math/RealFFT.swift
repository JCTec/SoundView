import Accelerate

/// Shared radix-2 real FFT primitive (vDSP `zrip`) behind the app's spectral
/// transforms — one FFT core, parameterized by each spec's own windowing, bin
/// packing, and scaling. `DemucsSpec` builds on it so the
/// vDSP plumbing lives in exactly one place (see `docs/MATH.md`).
///
/// Operates on a single length-`nfft` frame. Callers own the analysis/synthesis
/// window and the zrip unpack convention: after `forward`, `real[0]` holds the
/// DC term and `imag[0]` holds the Nyquist term (both packed at index 0), the
/// standard `vDSP_fft_zrip` layout.
struct RealFFT {
    let nfft: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup

    /// Fails only for non-power-of-two `nfft`. The `FFTSetup` is retained for the
    /// lifetime of the process (mirrors `STFT`/`DemucsSpec` — these specs are
    /// long-lived and a struct cannot deinit vDSP resources).
    init?(nfft: Int) {
        guard nfft > 0, nfft & (nfft - 1) == 0 else { return nil }
        self.nfft = nfft
        log2n = vDSP_Length(log2(Float(nfft)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        self.setup = setup
    }

    /// Forward transform of a length-`nfft` frame into packed split-complex
    /// (`real`/`imag` each length `nfft/2`, zrip layout). Values are unscaled;
    /// callers divide by 2 to recover true bin amplitudes.
    func forward(frame: [Float], real: inout [Float], imag: inout [Float]) {
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

    /// Inverse transform of packed split-complex back into a length-`nfft` frame.
    /// Leaves vDSP's `2·nfft` scale in place; the caller folds it into synthesis.
    func inverse(real: inout [Float], imag: inout [Float], into frame: inout [Float]) {
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
