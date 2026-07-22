import XCTest
@testable import SoundView

final class DemucsSpecTests: XCTestCase {
    func testRoundTripReconstructsSignal() throws {
        let spec = try XCTUnwrap(DemucsSpec())
        // Band-limited content well inside the kept bins (Nyquist bin is dropped).
        let samples = (0..<spec.segmentSamples).map { index -> Float in
            let time = Double(index) / 44_100
            return Float(0.5 * sin(2 * .pi * 220 * time) + 0.3 * sin(2 * .pi * 913 * time))
        }

        let reconstructed = spec.inverse(spec.forward(samples))
        XCTAssertEqual(reconstructed.count, samples.count)

        var signalEnergy: Double = 0
        var noiseEnergy: Double = 0
        for index in 0..<samples.count {
            signalEnergy += Double(samples[index] * samples[index])
            let error = Double(reconstructed[index] - samples[index])
            noiseEnergy += error * error
        }
        let snr = 10 * log10(signalEnergy / max(noiseEnergy, 1e-12))
        XCTAssertGreaterThan(snr, 35, "round-trip SNR \(snr) dB — transform must invert itself")
    }

    func testSilenceRoundTripsToSilence() throws {
        let spec = try XCTUnwrap(DemucsSpec())
        let silence = [Float](repeating: 0, count: spec.segmentSamples)
        let out = spec.inverse(spec.forward(silence))
        XCTAssertTrue(out.allSatisfy { abs($0) < 1e-6 })
    }

    func testForwardShapeMatchesManifest() throws {
        let spec = try XCTUnwrap(DemucsSpec())
        let spectrum = spec.forward([Float](repeating: 0.1, count: spec.segmentSamples))
        XCTAssertEqual(spectrum.real.count, 2_048 * 336)
        XCTAssertEqual(spectrum.imag.count, 2_048 * 336)
    }

    func testReflectPaddingMirrorsEdges() {
        let padded = DemucsSpec.reflectPadded([1, 2, 3, 4, 5], by: 2)
        XCTAssertEqual(padded, [3, 2, 1, 2, 3, 4, 5, 4, 3])
    }
}
