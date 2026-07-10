import Foundation
import Observation

/// Per-lane mix state shown in Stem View / Stem Desk.
struct StemLaneState: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var index: Int
    var volume: Float
    var isMuted: Bool
    var isSoloed: Bool
    var isLowEnergy: Bool
}

extension StemView {
    @Observable
    @MainActor
    final class ViewModel {
        private(set) var lanes: [StemLaneState]
        private(set) var playhead: TimeInterval = 0
        private(set) var isPlaying = false
        let mediaDuration: TimeInterval

        init(song: SongPackage) {
            mediaDuration = song.duration
            lanes = song.stems.map { stem in
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

        var effectiveGains: [Float] {
            MixMatrix.effectiveGains(
                lanes: lanes.map {
                    MixMatrix.Lane(volume: $0.volume, isMuted: $0.isMuted, isSoloed: $0.isSoloed)
                }
            )
        }

        func togglePlay() {
            isPlaying.toggle()
        }

        func skip(by delta: TimeInterval) {
            playhead = min(max(0, playhead + delta), mediaDuration)
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

        func requestExport() {
            // Export sheet in a later PR.
        }
    }
}
