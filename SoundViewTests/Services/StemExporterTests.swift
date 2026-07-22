import AVFoundation
import XCTest
@testable import SoundView

/// Export pipeline coverage (MISSION §3.1, gate D3-A). Runs on synthesized WAV
/// stems — no separation model required — so it validates mix render, zip
/// packaging, and M4A encoding directly.
final class StemExporterTests: XCTestCase {
    func testExportCurrentMixProducesPlayableWAV() async throws {
        let url = try await export(makeStems(), selection: .currentMix, format: .wav)
        XCTAssertEqual(url.pathExtension, "wav")
        let file = try AVAudioFile(forReading: url)
        XCTAssertGreaterThan(file.length, 0, "the rendered mix must contain audio")
    }

    func testExportAllStemsProducesNonEmptyZip() async throws {
        let url = try await export(makeStems(), selection: .allStems, format: .wav)
        XCTAssertEqual(url.pathExtension, "zip")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        XCTAssertGreaterThan(size, 0, "the stem zip must not be empty")
    }

    func testExportSinglePickedStemReturnsFileNotZip() async throws {
        let url = try await export(makeStems(), selection: .pickedStems(["vocals"]), format: .wav)
        XCTAssertEqual(url.pathExtension, "wav", "a single picked stem needs no archive")
    }

    func testM4AExportEncodesFile() async throws {
        let url = try await export(makeStems(), selection: .pickedStems(["vocals"]), format: .m4a)
        XCTAssertEqual(url.pathExtension, "m4a")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Helpers

    private func export(
        _ stems: [StemExporter.Stem], selection: StemExportSelection, format: StemExportFormat
    ) async throws -> URL {
        var result: URL?
        for try await event in StemExporter(title: "Idilio").export(
            stems: stems, selection: selection, format: format
        ) {
            if case .finished(let url) = event { result = url }
        }
        return try XCTUnwrap(result)
    }

    private func makeStems() throws -> [StemExporter.Stem] {
        [
            try makeStem(id: "vocals", frequency: 220),
            try makeStem(id: "drums", frequency: 440)
        ]
    }

    private func makeStem(id: String, frequency: Double) throws -> StemExporter.Stem {
        let sampleRate = 44_100.0
        let frames = Int(sampleRate)  // 1 second
        let channels = 2
        var interleaved = [Float](repeating: 0, count: frames * channels)
        for frame in 0..<frames {
            let value = Float(0.2 * sin(2 * .pi * frequency * Double(frame) / sampleRate))
            interleaved[frame * channels] = value
            interleaved[frame * channels + 1] = value
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(id)-\(UUID().uuidString).wav")
        try AudioFileIO.writeWAV(
            pcm: AudioFileIO.PCMBuffer(
                sampleRate: sampleRate, channelCount: channels, interleaved: interleaved
            ),
            to: url
        )
        return StemExporter.Stem(id: id, name: id.capitalized, url: url, gain: 1)
    }
}
