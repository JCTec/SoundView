import Foundation

/// A pending export, carried into a `.sheet(item:)` from an export affordance.
struct StemExportRequest: Identifiable {
    let id = UUID()
    let stems: [StemExporter.Stem]
    let selection: StemExportSelection
}

/// Bridges the player's live lanes + effective gains and the on-disk stem files
/// into `StemExporter.Stem` inputs. Gains fold in solo/mute/volume so the
/// current-mix render matches what the listener hears.
enum StemExportInputs {
    @MainActor
    static func build(
        song: SongPackage,
        player: StemPlayerModel,
        fileStore: any FileStoreProtocol
    ) async -> [StemExporter.Stem] {
        let urls = (try? await fileStore.stemAudioURLs(id: song.id)) ?? []
        let gains = player.effectiveGains
        return player.lanes.enumerated().compactMap { index, lane in
            guard let url = urls.first(where: { $0.id == lane.id })?.url else { return nil }
            let gain = index < gains.count ? gains[index] : 1
            return StemExporter.Stem(id: lane.id, name: lane.name, url: url, gain: gain)
        }
    }
}
