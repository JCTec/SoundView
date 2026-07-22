import Foundation
import SwiftUI

/// Composition root — protocol services injected via environment.
@MainActor
@Observable
final class AppEnvironment {
    let fileStore: any FileStoreProtocol
    let stemSeparator: any StemSeparating
    let modelCatalog: any ModelCataloging
    let stemMixer: StemMixer
    /// Human storage sentence for Settings (“SoundView in iCloud Drive”).
    private(set) var storageDisplaySentence: String = "SoundView in iCloud Drive"
    private(set) var syncStatus: SyncStatus = .syncedWithiCloud

    init(fileStore: (any FileStoreProtocol)? = nil) {
        // Configure logging at the composition root (independent of scene lifecycle):
        // os_log + a retrievable file, then surface any prior unclean exit.
        Log.configure(sink: CompositeLogSink([OSLogSink(), FileLogSink()]))
        Log.recoverFromUncleanExit()
        Log.info(.lifecycle, "launch", Log.memory())
        DeviceKind.warmUp()  // capture the device idiom on the main actor (see DeviceKind)

        let store: any FileStoreProtocol
        if let fileStore {
            store = fileStore
        } else if ProcessInfo.processInfo.arguments.contains("-previewLibrary") {
            store = PreviewFileStore()
        } else if let production = try? FileStore() {
            store = production
        } else {
            store = PreviewFileStore(syncStatus: .onThisDevice)
        }
        self.fileStore = store
        let catalog = ModelCatalog()
        self.modelCatalog = catalog
        self.stemSeparator = StemSeparator(fileStore: store, catalog: catalog)
        self.stemMixer = StemMixer()
    }

    static let preview = AppEnvironment(fileStore: PreviewFileStore())

    func refreshStorageStatus() async {
        storageDisplaySentence = await fileStore.storageDisplaySentence()
        syncStatus = await fileStore.currentSyncStatus()
    }

    /// DEBUG only: import bundled `Idilio.mp3` into the real FileStore when missing.
    func seedDevelopmentLibraryIfNeeded() async {
        await DevelopmentLibrarySeeder.seedIfNeeded(using: fileStore)
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
