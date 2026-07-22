import Foundation

/// Seeds the real `FileStore` with bundled development audio on **DEBUG** launches.
///
/// This is **not** stem separation — it only imports the full mix so library / package /
/// duration / future separation work against a real track. Waveforms and separation UI
/// remain placeholders until those services ship.
enum DevelopmentLibrarySeeder {
    /// Bundled track name (see `Fixtures/Audio/Idilio.mp3` → app resources).
    static let fixtureFileName = "Idilio"
    static let fixtureExtension = "mp3"
    /// Stable library title after import.
    static let libraryTitle = "Idilio"

    /// Serializes concurrent `.task` callers (App + Library + Sidebar) so we only import once.
    private static let seedGate = SeedGate()

    /// Import Idilio once when missing from the library.
    static func seedIfNeeded(using store: any FileStoreProtocol) async {
        #if DEBUG
        await seedGate.run {
            do {
                let songs = try await store.listSongs()
                if songs.contains(where: {
                    $0.title.caseInsensitiveCompare(libraryTitle) == .orderedSame
                }) {
                    return
                }
                guard let url = bundledIdilioURL() else {
                    // Fixture not in app bundle — skip quietly (Release / misconfigured project).
                    return
                }
                _ = try await store.importAudio(from: url, autoSeparate: .default)
            } catch {
                // Seeding must never crash a DEBUG launch.
                return
            }
        }
        #endif
    }

    private actor SeedGate {
        private var didRun = false

        func run(_ work: @Sendable () async -> Void) async {
            guard !didRun else { return }
            didRun = true
            await work()
        }
    }

    static func bundledIdilioURL() -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: fixtureFileName, withExtension: fixtureExtension) {
            return url
        }
        // XcodeGen folder resource may nest under Audio/
        if let url = bundle.url(
            forResource: fixtureFileName,
            withExtension: fixtureExtension,
            subdirectory: "Audio"
        ) {
            return url
        }
        if let url = bundle.url(
            forResource: fixtureFileName,
            withExtension: fixtureExtension,
            subdirectory: "AudioFixtures"
        ) {
            return url
        }
        return nil
    }
}
