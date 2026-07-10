import Foundation

/// Lifecycle of an automatic / user-triggered separation job.
enum SeparationStatus: String, Codable, Sendable {
    case pending
    case running
    case finished
    case failed
}

/// Separation fields embedded in `manifest.json`.
struct SeparationState: Codable, Equatable, Sendable {
    var status: SeparationStatus
    var progress: Double
    var mode: String
    var lastError: String?

    static func pending(mode: StemMode) -> SeparationState {
        SeparationState(status: .pending, progress: 0, mode: mode.rawValue, lastError: nil)
    }
}

/// One stem file entry — relative name under `stems/` only.
struct StemFileEntry: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var index: Int
    /// Relative path under `stems/`, e.g. `00-vocals.wav`.
    var fileName: String
    var isLowEnergy: Bool
}

/// On-disk schema for a `.soundview` package (`manifest.json`).
/// Paths inside the package are **relative file names only** — never absolute.
struct PackageManifest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var duration: TimeInterval
    /// Relative name inside the package root, e.g. `original.mp3`.
    var originalFileName: String
    /// Uppercase extension-style label for UI (`MP3`, `WAV`, `M4A`).
    var originalFormat: String
    var intendedStemMode: String
    var separation: SeparationState
    var stems: [StemFileEntry]

    func toSongPackage(relativeDayLabel: String) -> SongPackage {
        let finished = separation.status == .finished && !stems.isEmpty
        let progress: Double? = switch separation.status {
        case .running: separation.progress
        case .pending, .failed: nil
        case .finished: nil
        }

        return SongPackage(
            id: id,
            title: title,
            duration: duration,
            stemCount: finished ? stems.count : nil,
            formatLabel: originalFormat,
            relativeDayLabel: relativeDayLabel,
            stems: stems
                .sorted { $0.index < $1.index }
                .map {
                    StemDescriptor(
                        id: $0.id,
                        name: $0.name,
                        index: $0.index,
                        isLowEnergy: $0.isLowEnergy
                    )
                },
            separationProgress: progress
        )
    }
}

/// Optional mix state written as `mix.json` (gains / mute / solo).
struct MixStateDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var gains: [String: Float]
    var muted: [String]
    var soloed: [String]

    static let empty = MixStateDocument(
        schemaVersion: currentSchemaVersion,
        gains: [:],
        muted: [],
        soloed: []
    )
}
