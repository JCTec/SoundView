import Foundation
import SwiftUI

/// Composition root — protocol services injected via environment.
@MainActor
@Observable
final class AppEnvironment {
    let fileStore: any FileStoreProtocol
    /// Human storage sentence for Settings (“SoundView in iCloud Drive”).
    private(set) var storageDisplaySentence: String = "SoundView in iCloud Drive"
    private(set) var syncStatus: SyncStatus = .syncedWithiCloud

    init(fileStore: (any FileStoreProtocol)? = nil) {
        if let fileStore {
            self.fileStore = fileStore
        } else if let production = try? FileStore() {
            self.fileStore = production
        } else {
            // Extremely rare: storage root could not be created.
            self.fileStore = PreviewFileStore(syncStatus: .onThisDevice)
        }
    }

    static let preview = AppEnvironment(fileStore: PreviewFileStore())

    func refreshStorageStatus() async {
        storageDisplaySentence = await fileStore.storageDisplaySentence()
        syncStatus = await fileStore.currentSyncStatus()
    }
}

/// Environment injection without crossing MainActor isolation on `EnvironmentKey`.
private struct AppEnvironmentKey: @preconcurrency EnvironmentKey {
    static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    @MainActor
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] ?? .preview }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
