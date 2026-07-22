import Foundation

/// Separation engine the listener uses. A single bundled Demucs studio engine
/// (Meta's `htdemucs_ft`). No multi-tier product path.
enum SeparationQuality: String, CaseIterable, Identifiable, Sendable {
    /// Bundled Demucs `htdemucs_ft` 4-stem (Meta checkpoint → Core ML).
    case studio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studio: return "Studio"
        }
    }

    /// One human sentence — never a path, never a model name (A-rules).
    var subtitle: String {
        switch self {
        case .studio:
            return "On this device · best quality."
        }
    }

    static let `default`: SeparationQuality = .studio
}
