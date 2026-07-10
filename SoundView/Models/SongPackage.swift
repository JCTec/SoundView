import Foundation

/// Human-facing song package — original + stems + mix state.
/// UI never exposes folder paths.
struct SongPackage: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var duration: TimeInterval
    var stemCount: Int?
    var isSeparated: Bool { stemCount != nil && (stemCount ?? 0) > 0 }
    var formatLabel: String
    var relativeDayLabel: String
    var stems: [StemDescriptor]
    var separationProgress: Double?

    static let samples: [SongPackage] = [
        SongPackage(
            id: "midnight",
            title: "Midnight Drive",
            duration: 231,
            stemCount: 5,
            formatLabel: "WAV",
            relativeDayLabel: "Today",
            stems: [
                StemDescriptor(id: "v", name: "Vocals", index: 0),
                StemDescriptor(id: "d", name: "Drums", index: 1),
                StemDescriptor(id: "b", name: "Bass", index: 2),
                StemDescriptor(id: "g", name: "Guitar", index: 3),
                StemDescriptor(id: "k", name: "Keys", index: 4)
            ],
            separationProgress: nil
        ),
        SongPackage(
            id: "rehearsal",
            title: "Rehearsal — bridge take 3",
            duration: 127,
            stemCount: nil,
            formatLabel: "WAV · recorded",
            relativeDayLabel: "Yesterday",
            stems: [],
            separationProgress: nil
        )
    ]
}

struct StemDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var index: Int
    var isLowEnergy: Bool = false
}
