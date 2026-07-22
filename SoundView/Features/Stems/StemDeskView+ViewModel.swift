import Foundation
import Observation

extension StemDeskView {
    /// Thin coordinator: resolves the song package and owns the shared player.
    /// All playback / mix / viewport state lives in `StemPlayerModel` — one source
    /// of truth for the desk, the phone stack, and the sidebar jump list.
    @Observable
    @MainActor
    final class ViewModel {
        private(set) var song: SongPackage?
        let player = StemPlayerModel()

        private var songID: String?
        private var fileStore: (any FileStoreProtocol)?
        private var mixer: (any StemMixing)?

        init(songID: String?) {
            self.songID = songID
        }

        func bind(mixer: any StemMixing, fileStore: any FileStoreProtocol) {
            self.mixer = mixer
            self.fileStore = fileStore
        }

        func load(songID: String?, store: any FileStoreProtocol) async {
            self.songID = songID
            fileStore = store
            guard let songID else {
                song = nil
                return
            }
            if let loaded = try? await store.song(id: songID) {
                song = loaded
            } else {
                let songs = (try? await store.listSongs()) ?? []
                song = songs.first { $0.id == songID }
            }
            if let song, song.isSeparated, let mixer {
                await player.load(song: song, mixer: mixer, fileStore: store)
            }
        }

        func focusStem(id: String?) {
            // Reserved: scroll-to-lane once the desk gains a scroll proxy.
            _ = id
        }

        func teardown() {
            player.teardown()
        }
    }
}
