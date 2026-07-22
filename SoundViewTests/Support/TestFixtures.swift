import Foundation
import XCTest

/// Shared real-audio fixtures for integration-style tests.
///
/// Canonical on-disk location: `Fixtures/Audio/` (repo root).
/// Copied into the test bundle as a folder reference named `Audio` / `AudioFixtures`.
///
/// `Test.mp3` — stereo 44.1 kHz, ~308.7 s (~5:09). Product: MP3 is open-only.
enum TestFixtures {
    /// Bundle URL for the canonical music test track.
    static var testMP3URL: URL {
        let bundle = Bundle(for: BundleToken.self)
        let candidates: [URL?] = [
            bundle.url(forResource: "Test", withExtension: "mp3"),
            bundle.url(forResource: "Test", withExtension: "mp3", subdirectory: "Audio"),
            bundle.url(forResource: "Test", withExtension: "mp3", subdirectory: "AudioFixtures"),
            bundle.url(forResource: "Test", withExtension: "mp3", subdirectory: "Fixtures/Audio"),
            bundle.resourceURL?.appendingPathComponent("Audio/Test.mp3"),
            bundle.resourceURL?.appendingPathComponent("AudioFixtures/Test.mp3"),
            bundle.bundleURL.appendingPathComponent("Audio/Test.mp3"),
            bundle.bundleURL.appendingPathComponent("AudioFixtures/Test.mp3")
        ]
        if let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) {
            return url
        }
        XCTFail(
            "Test.mp3 missing from test resources — expected Fixtures/Audio in project.yml"
        )
        preconditionFailure("Test.mp3 fixture not found")
    }

    /// Approximate duration from `afinfo` (seconds) — use with tolerance in assertions.
    static let testMP3ExpectedDuration: TimeInterval = 308.74

    /// Same audio as `Idilio.mp3` (development library track) until we diversify fixtures.
    static var idilioMP3URL: URL {
        let bundle = Bundle(for: BundleToken.self)
        let candidates: [URL?] = [
            bundle.url(forResource: "Idilio", withExtension: "mp3"),
            bundle.url(forResource: "Idilio", withExtension: "mp3", subdirectory: "Audio"),
            repositoryAudioDirectory.appendingPathComponent("Idilio.mp3")
        ]
        if let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) {
            return url
        }
        // Fall back to Test.mp3 (identical bytes today).
        return testMP3URL
    }

    /// On-disk path for tools/scripts (not used inside the simulator bundle).
    static var repositoryAudioDirectory: URL {
        // SoundViewTests/Support → repo root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // SoundViewTests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Fixtures/Audio", isDirectory: true)
    }
}

private final class BundleToken: NSObject {}
