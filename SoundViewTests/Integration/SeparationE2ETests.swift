import AVFoundation
@testable import SoundView
import XCTest

/// End-to-end separation validation (docs/RELEASE.md).
///
/// **Studio (Demucs `htdemucs_ft`):** runs only when the four Core ML models are
/// bundled; otherwise `XCTSkip`s. The Python parity gate (`convert_htdemucs.py
/// --validate`) proves numerical fidelity to Meta's forward pass; this test proves
/// the Swift pipeline produces four real, non-silent stems on real audio.
final class SeparationE2ETests: XCTestCase {
    func testDemucsProducesFourNonZeroStems() async throws {
        try XCTSkipUnless(
            CoreMLDemucsBackend.isModelBundled,
            "Studio (Demucs) models not bundled — run tools/convert_htdemucs.py"
        )
        let url = try trimmedFixture(seconds: 8)
        let (stems, seconds) = try await runBackend(CoreMLDemucsBackend(), url: url)
        XCTAssertEqual(stems.count, 4, "Demucs htdemucs_ft produces four stems")
        for stem in stems {
            let pcm = try AudioFileIO.loadPCM(from: stem.url)
            XCTAssertFalse(
                pcm.interleaved.allSatisfy { $0 == 0 },
                "stem \(stem.key) is all-zero"
            )
        }
        print(String(format: "[E2E] Demucs runtime %.1fs · %d stems", seconds, stems.count))
    }

    // MARK: - Helpers

    private func trimmedFixture(seconds: Double) throws -> URL {
        let full = try AudioFileIO.loadPCMCanonical(from: TestFixtures.idilioMP3URL)
        let frames = min(full.frameCount, Int(full.sampleRate * seconds))
        let clip = AudioFileIO.PCMBuffer(
            sampleRate: full.sampleRate,
            channelCount: full.channelCount,
            interleaved: Array(full.interleaved[0..<(frames * full.channelCount)])
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("idilio-clip-\(UUID().uuidString).wav")
        try AudioFileIO.writeWAV(pcm: clip, to: url)
        return url
    }

    private struct StemOut {
        var key: String
        var url: URL
    }

    private func runBackend(
        _ backend: any StemSeparationBackend,
        url: URL
    ) async throws -> (stems: [StemOut], seconds: TimeInterval) {
        let started = Date()
        var produced: [StemOut] = []
        for try await event in backend.separate(
            originalURL: url,
            title: "E2E",
            duration: 8,
            mode: .four
        ) {
            if case .stem(let stem) = event {
                produced.append(StemOut(key: stem.id, url: stem.fileURL))
            }
        }
        return (produced, Date().timeIntervalSince(started))
    }
}
