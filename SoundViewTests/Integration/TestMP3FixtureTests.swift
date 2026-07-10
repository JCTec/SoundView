import AVFoundation
import XCTest
@testable import SoundView

/// Smoke tests against real `Test.mp3` (open-only MP3 path from product spec).
final class TestMP3FixtureTests: XCTestCase {
    func testFixtureIsPresentAndReadable() throws {
        let url = TestFixtures.testMP3URL
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension.lowercased(), "mp3")
    }

    func testFixtureLoadsWithAVAudioFile() throws {
        let url = TestFixtures.testMP3URL
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        XCTAssertEqual(format.sampleRate, 44_100, accuracy: 0.1)
        XCTAssertEqual(format.channelCount, 2)

        let duration = Double(file.length) / format.sampleRate
        XCTAssertEqual(
            duration,
            TestFixtures.testMP3ExpectedDuration,
            accuracy: 1.0,
            "Duration should match ~5:09 music fixture"
        )
        XCTAssertGreaterThan(file.length, 0)
    }

    func testFixtureDurationUsefulForViewportMath() throws {
        let url = TestFixtures.testMP3URL
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate

        // Mid-song scrub window should stay centered without clamping past EOF.
        let range = ViewportMath.visibleRange(
            playhead: duration / 2,
            mediaDuration: duration,
            visibleDuration: 20
        )
        XCTAssertEqual(range.duration, 20, accuracy: 0.01)
        XCTAssertGreaterThan(range.start, 0)
        XCTAssertLessThan(range.end, duration)
    }

    func testPeakDecimationFromDecodedSnippet() throws {
        let url = TestFixtures.testMP3URL
        let file = try AVAudioFile(forReading: url)
        let frameCount = min(AVAudioFrameCount(file.length), 44_100) // 1 second
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: frameCount
        ) else {
            return XCTFail("Could not allocate PCM buffer")
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else {
            return XCTFail("Missing float channel data")
        }

        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let peaks = PeakDecimation.minMaxPeaks(samples: samples, bucketCount: 100)
        XCTAssertEqual(peaks.count, 100)
        // Music should not be pure digital silence across a whole second.
        let hasEnergy = peaks.contains { abs($0.min) > 0.001 || abs($0.max) > 0.001 }
        XCTAssertTrue(hasEnergy, "Expected audible energy in first second of Test.mp3")
    }
}
