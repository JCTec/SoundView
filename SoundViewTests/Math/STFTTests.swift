import XCTest
@testable import SoundView

final class STFTTests: XCTestCase {
    func testRoundTripReconstructsSine() throws {
        let stft = try XCTUnwrap(STFT(nfft: 1_024))
        let sampleCount = 8_192
        let signal = (0..<sampleCount).map { index in
            Float(sin(2 * .pi * 440 * Double(index) / 44_100))
        }

        let spectrum = stft.forward(signal)
        let reconstructed = stft.inverse(spectrum, sampleCount: sampleCount)

        // Skip the first/last window where analysis padding dominates.
        let margin = 1_024
        for index in margin..<(sampleCount - margin) {
            XCTAssertEqual(
                reconstructed[index], signal[index], accuracy: 0.01,
                "sample \(index)"
            )
        }
    }

    func testRoundTripSilenceStaysSilent() throws {
        let stft = try XCTUnwrap(STFT(nfft: 1_024))
        let silence = [Float](repeating: 0, count: 4_096)
        let out = stft.inverse(stft.forward(silence), sampleCount: silence.count)
        XCTAssertTrue(out.allSatisfy { abs($0) < 1e-6 })
    }

    func testSpectrumShape() throws {
        let stft = try XCTUnwrap(STFT(nfft: 1_024))
        let spectrum = stft.forward([Float](repeating: 0.5, count: 2_048))
        XCTAssertEqual(spectrum.binCount, 513)
        XCTAssertEqual(spectrum.frameCount, 8) // ceil(2048 / 256)
        XCTAssertEqual(spectrum.real.count, spectrum.frameCount * spectrum.binCount)
    }

    func testRejectsNonPowerOfTwo() {
        XCTAssertNil(STFT(nfft: 1_000))
    }
}
