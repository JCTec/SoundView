#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Human device word for storage sentences ("On this iPhone / iPad / Mac").
/// The only sanctioned UIKit import outside nothing — a leaf lookup, no UI.
enum DeviceKind {
    static var localStorageSentence: String {
        "On this \(deviceWord)"
    }

    static var deviceWord: String {
        #if os(macOS)
        return "Mac"
        #elseif canImport(UIKit)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "iPad"
        case .mac: return "Mac"
        default: return "iPhone"
        }
        #else
        return "device"
        #endif
    }
}
