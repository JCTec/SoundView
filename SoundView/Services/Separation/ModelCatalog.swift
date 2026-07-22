import Foundation

/// A separation engine the app can offer, with live availability.
struct SeparationEngine: Identifiable, Sendable {
    let id: SeparationQuality
    let displayName: String
    let tier: SeparationTier
    let isAvailable: Bool
}

enum SeparationTier: String, Sendable {
    /// Bundled Demucs `htdemucs_ft` (Meta) — the sole product engine.
    case studio
}

/// Engine registry. A single studio engine: Meta's official Demucs.
protocol ModelCataloging: Sendable {
    func engines() -> [SeparationEngine]
    func engine(for quality: SeparationQuality) -> SeparationEngine
    func isAvailable(_ quality: SeparationQuality) -> Bool
    func backend(for quality: SeparationQuality) -> (any StemSeparationBackend)?
}

/// Default catalog. Availability is derived from the filesystem on every call.
///
/// - **Studio**: bundled Demucs `htdemucs_ft` when its four Core ML models +
///   manifest ship.
/// - **DEBUG only**: if the models are missing, falls back to the Idilio
///   reference pack so UI/dev flows still run — never a product quality claim.
final class ModelCatalog: ModelCataloging, @unchecked Sendable {
    func isAvailable(_ quality: SeparationQuality) -> Bool {
        switch quality {
        case .studio:
            if CoreMLDemucsBackend.isModelBundled { return true }
            #if DEBUG
            return true // reference pack / soft-dev path
            #else
            return CoreMLDemucsBackend.isModelBundled
            #endif
        }
    }

    func engine(for quality: SeparationQuality) -> SeparationEngine {
        SeparationEngine(
            id: quality,
            displayName: quality.title,
            tier: .studio,
            isAvailable: isAvailable(quality)
        )
    }

    func engines() -> [SeparationEngine] {
        SeparationQuality.allCases.map(engine(for:))
    }

    func backend(for quality: SeparationQuality) -> (any StemSeparationBackend)? {
        switch quality {
        case .studio:
            if CoreMLDemucsBackend.isModelBundled {
                return CoreMLDemucsBackend()
            }
            #if DEBUG
            // Dev-only: Idilio reference stems so Separate still demos without the
            // converted models. Never marketed as the studio engine.
            return ReferenceDemucsBackend()
            #else
            return nil
            #endif
        }
    }
}
