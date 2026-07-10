import Foundation
import Observation

extension LibraryView {
    @Observable
    @MainActor
    final class ViewModel {
        private(set) var songs: [SongPackage] = []
        private(set) var syncStatus: SyncStatus = .syncedWithiCloud
        private(set) var isLoading = false
        private(set) var lastErrorMessage: String?

        private var fileStore: any FileStoreProtocol

        init(fileStore: any FileStoreProtocol) {
            self.fileStore = fileStore
        }

        func updateStore(_ store: any FileStoreProtocol) {
            fileStore = store
        }

        func load() async {
            isLoading = true
            defer { isLoading = false }
            do {
                songs = try await fileStore.listSongs()
                syncStatus = await fileStore.currentSyncStatus()
                lastErrorMessage = nil
            } catch {
                songs = []
                syncStatus = await fileStore.currentSyncStatus()
                lastErrorMessage = error.localizedDescription
            }
        }

        /// Import a user-selected audio URL (document picker / drop).
        @discardableResult
        func importAudio(from url: URL, mode: StemMode = .default) async -> SongPackage? {
            do {
                let package = try await fileStore.importAudio(from: url, autoSeparate: mode)
                await load()
                return package
            } catch {
                lastErrorMessage = error.localizedDescription
                return nil
            }
        }

        func deleteSong(id: String) async {
            do {
                try await fileStore.deleteSong(id: id)
                await load()
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }

        func reportError(_ message: String) {
            lastErrorMessage = message
        }
    }
}
