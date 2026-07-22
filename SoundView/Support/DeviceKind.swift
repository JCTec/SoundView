#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Human device word for storage sentences ("On this iPhone / iPad / Mac").
/// The only sanctioned UIKit import outside nothing — a leaf lookup, no UI.
///
/// `UIDevice.current` is main-actor-isolated in recent SDKs (reading it off the
/// main actor is a Swift 6 error), but the idiom is constant per run and is needed
/// by nonisolated, `Sendable` UI-copy (`SyncStatus.sentence`, `StorageRoot`). So we
/// capture it once on the main actor at launch (`warmUp`) and let those callers
/// read the cache synchronously.
enum DeviceKind {
    // Written once by `warmUp()` on the main actor at launch, read from nonisolated
    // UI-copy thereafter. The default is correct on macOS and a safe placeholder on
    // iOS until `warmUp()` runs (before any UI appears).
    #if os(macOS)
    nonisolated(unsafe) private static var cached = "Mac"
    #else
    nonisolated(unsafe) private static var cached = "iPhone"
    #endif

    /// Capture the device idiom on the main actor. Call once at app launch.
    @MainActor static func warmUp() {
        #if canImport(UIKit) && !os(macOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: cached = "iPad"
        case .mac: cached = "Mac"
        default: cached = "iPhone"
        }
        #endif
    }

    static var deviceWord: String { cached }

    static var localStorageSentence: String { "On this \(deviceWord)" }
}
