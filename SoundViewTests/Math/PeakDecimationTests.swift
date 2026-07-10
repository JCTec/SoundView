import XCTest
@testable import SoundView

final class PeakDecimationTests: XCTestCase {
    func testEmptySamples() {
        XCTAssertTrue(PeakDecimation.minMaxPeaks(samples: [], bucketCount: 10).isEmpty)
    }

    func testKnownMinMax() {
        let samples: [Float] = [-1, 0, 1, 0.5, -0.5, 0.25]
        let peaks = PeakDecimation.minMaxPeaks(samples: samples, bucketCount: 2)
        XCTAssertEqual(peaks.count, 2)
        XCTAssertEqual(peaks[0].min, -1, accuracy: 0.0001)
        XCTAssertEqual(peaks[0].max, 1, accuracy: 0.0001)
    }

    func testChunkedHigherOrder() {
        let chunks = [1, 2, 3, 4, 5].chunked(into: 2)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks.last, [5])
    }
}
