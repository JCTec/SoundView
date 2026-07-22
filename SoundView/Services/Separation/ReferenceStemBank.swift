import Foundation

/// Bundled Demucs reference stems for known development tracks (Idilio).
///
/// These WAVs come from offline `htdemucs_6s` (same family as the user's Python pass):
/// vocals, drums, bass, guitar, piano, other.
///
/// On-device Core ML HTDemucs can replace this bank later without changing the UI pipeline.
enum ReferenceStemBank {
    static let idilioTitle = "Idilio"

    /// Resource folder inside the app bundle (`Idilio-stems/`).
    static let idilioFolder = "Idilio-stems"

    static let sixKeys = ["vocals", "drums", "bass", "guitar", "piano", "other"]

    /// Whether a full 6-stem reference pack is present in the bundle.
    static var isIdilioPackAvailable: Bool {
        sixKeys.allSatisfy { key in
            stemURL(folder: idilioFolder, key: key) != nil
        }
    }

    static func stemURL(folder: String, key: String) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: key, withExtension: "wav", subdirectory: folder) {
            return url
        }
        // Flat resource names: `Idilio-stems_vocals.wav` fallback not used.
        if let root = bundle.resourceURL?.appendingPathComponent(folder, isDirectory: true) {
            let url = root.appendingPathComponent("\(key).wav")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    static func matchesIdilio(title: String, duration: TimeInterval) -> Bool {
        title.caseInsensitiveCompare(idilioTitle) == .orderedSame
            && abs(duration - 308.7) < 2.0
    }
}
