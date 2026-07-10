import Foundation
import Observation

extension StemDeskView {
    @Observable
    @MainActor
    final class ViewModel {
        private(set) var song: SongPackage?
        private(set) var lanes: [StemLaneState] = []
        private(set) var playhead: TimeInterval = 0
        private(set) var isPlaying = false
        private var songID: String?

        init(songID: String?) {
            self.songID = songID
        }

        func load(songID: String?, store: any FileStoreProtocol) async {
            self.songID = songID
            guard let songID else {
                song = nil
                lanes = []
                return
            }
            if let loaded = try? await store.song(id: songID) {
                song = loaded
            } else {
                let songs = (try? await store.listSongs()) ?? []
                song = songs.first { $0.id == songID }
            }
            rebuildLanes()
        }

        func focusStem(id: String?) {
            // Jump-only: highlight handled by view; no reorder.
            _ = id
        }

        func togglePlay() { isPlaying.toggle() }

        func skip(by delta: TimeInterval) {
            let duration = song?.duration ?? 0
            playhead = min(max(0, playhead + delta), duration)
        }

        func toggleMute(id: String) {
            guard let index = lanes.firstIndex(where: { $0.id == id }) else { return }
            lanes[index].isMuted.toggle()
        }

        func toggleSolo(id: String) {
            guard let index = lanes.firstIndex(where: { $0.id == id }) else { return }
            lanes[index].isSoloed.toggle()
        }

        func setVolume(id: String, volume: Float) {
            guard let index = lanes.firstIndex(where: { $0.id == id }) else { return }
            lanes[index].volume = volume
        }

        func beginSeparation(mode: StemMode) {
            _ = mode
            // StemSeparator service next.
        }

        func requestExport() {}

        private func rebuildLanes() {
            lanes = (song?.stems ?? []).map { stem in
                StemLaneState(
                    id: stem.id,
                    name: stem.name,
                    index: stem.index,
                    volume: 1,
                    isMuted: false,
                    isSoloed: false,
                    isLowEnergy: stem.isLowEnergy
                )
            }
        }
    }
}
