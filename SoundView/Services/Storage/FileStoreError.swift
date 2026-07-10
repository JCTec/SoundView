import Foundation

/// Typed failures for package storage — messages are safe to log; UI maps to friendly copy.
enum FileStoreError: Error, Equatable, LocalizedError, Sendable {
    case rootNotDirectory(String)
    case packageNotFound(String)
    case invalidManifest(String)
    case unreadableAudio(String)
    case securityScopedAccessDenied
    case ioFailed(String)

    var errorDescription: String? {
        switch self {
        case .rootNotDirectory(let name):
            return "Storage location “\(name)” is not a folder."
        case .packageNotFound(let id):
            return "Song package “\(id)” was not found."
        case .invalidManifest(let detail):
            return "Package manifest is invalid: \(detail)"
        case .unreadableAudio(let name):
            return "Could not read audio from “\(name)”."
        case .securityScopedAccessDenied:
            return "Permission to read the selected file was denied."
        case .ioFailed(let detail):
            return detail
        }
    }
}
