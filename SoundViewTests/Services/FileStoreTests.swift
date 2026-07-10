import AVFoundation
import XCTest
@testable import SoundView

final class FileStoreTests: XCTestCase {
    private var tempRoot: URL!
    private var store: FileStore!

    override func setUp() async throws {
        try await super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundView-FileStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        store = try FileStore(testingRoot: tempRoot)
    }

    override func tearDown() async throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        store = nil
        tempRoot = nil
        try await super.tearDown()
    }

    func testEmptyLibrary() async throws {
        let songs = try await store.listSongs()
        XCTAssertTrue(songs.isEmpty)
        let status = await store.currentSyncStatus()
        XCTAssertEqual(status, .onThisDevice)
        let sentence = await store.storageDisplaySentence()
        XCTAssertFalse(sentence.contains("/"))
        XCTAssertFalse(sentence.lowercased().contains("users"))
    }

    func testImportListsAndReadsPackage() async throws {
        let source = TestFixtures.testMP3URL
        let package = try await store.importAudio(from: source, autoSeparate: .four)

        XCTAssertFalse(package.id.isEmpty)
        XCTAssertEqual(package.formatLabel, "MP3")
        XCTAssertEqual(package.relativeDayLabel, "Today")
        XCTAssertNil(package.stemCount)
        XCTAssertEqual(
            package.duration,
            TestFixtures.testMP3ExpectedDuration,
            accuracy: 1.0
        )

        let listed = try await store.listSongs()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed[0].id, package.id)

        let fetched = try await store.song(id: package.id)
        XCTAssertEqual(fetched?.id, package.id)
        XCTAssertEqual(fetched?.title, package.title)

        let originalURL = try await store.originalAudioURL(id: package.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertEqual(originalURL.pathExtension.lowercased(), "mp3")
        // Package-relative original name only — never the user's source path.
        XCTAssertEqual(originalURL.lastPathComponent, "original.mp3")
    }

    func testImportCreatesManifestAndMixOnDisk() async throws {
        let package = try await store.importAudio(
            from: TestFixtures.testMP3URL,
            autoSeparate: .six
        )
        let packageURL = try await store.packageDirectoryURL(id: package.id)
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let mixURL = packageURL.appendingPathComponent("mix.json")
        let stemsDir = packageURL.appendingPathComponent("stems", isDirectory: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: mixURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: stemsDir.path))

        let data = try Data(contentsOf: manifestURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["id"] as? String, package.id)
        XCTAssertEqual(json["intendedStemMode"] as? String, "6")
        XCTAssertEqual(json["originalFileName"] as? String, "original.mp3")
        // No absolute paths in the manifest.
        let encoded = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(encoded.contains("/Users/"))
        XCTAssertFalse(encoded.contains(tempRoot.path))
    }

    func testDeleteSongRemovesPackage() async throws {
        let package = try await store.importAudio(
            from: TestFixtures.testMP3URL,
            autoSeparate: .two
        )
        try await store.deleteSong(id: package.id)
        let listed = try await store.listSongs()
        XCTAssertTrue(listed.isEmpty)
        let fetched = try await store.song(id: package.id)
        XCTAssertNil(fetched)
    }

    func testUpdateSeparationProgress() async throws {
        let package = try await store.importAudio(
            from: TestFixtures.testMP3URL,
            autoSeparate: .four
        )
        let running = try await store.updateSeparation(
            id: package.id,
            status: .running,
            progress: 0.42,
            stems: nil
        )
        XCTAssertEqual(running.separationProgress ?? -1, 0.42, accuracy: 0.001)

        let stem = StemFileEntry(
            id: "v",
            name: "Vocals",
            index: 0,
            fileName: "00-vocals.wav",
            isLowEnergy: false
        )
        let finished = try await store.updateSeparation(
            id: package.id,
            status: .finished,
            progress: 1,
            stems: [stem]
        )
        XCTAssertEqual(finished.stemCount, 1)
        XCTAssertTrue(finished.isSeparated)
        XCTAssertNil(finished.separationProgress)
        XCTAssertEqual(finished.stems.first?.name, "Vocals")
    }

    func testImportingSuffixNotListed() async throws {
        // Manually drop a half-written package; list must ignore it.
        let packages = tempRoot.appendingPathComponent("Packages", isDirectory: true)
        let partial = packages.appendingPathComponent(
            "partial.soundview.importing",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        let songs = try await store.listSongs()
        XCTAssertTrue(songs.isEmpty)
    }
}

final class RelativeDayLabelTests: XCTestCase {
    func testTodayYesterdayAndOlder() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 15))!

        let today = now
        XCTAssertEqual(RelativeDayLabel.make(for: today, now: now, calendar: calendar), "Today")

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(
            RelativeDayLabel.make(for: yesterday, now: now, calendar: calendar),
            "Yesterday"
        )

        let threeDays = calendar.date(byAdding: .day, value: -3, to: now)!
        XCTAssertEqual(
            RelativeDayLabel.make(for: threeDays, now: now, calendar: calendar),
            "3 days ago"
        )
    }
}

final class PackageLayoutTests: XCTestCase {
    func testOriginalFileNameNormalization() {
        XCTAssertEqual(PackageLayout.originalFileName(forSourceExtension: "mp3"), "original.mp3")
        XCTAssertEqual(PackageLayout.originalFileName(forSourceExtension: ".WAV"), "original.wav")
        XCTAssertEqual(PackageLayout.originalFileName(forSourceExtension: ""), "original.bin")
    }

    func testPackageURLsAreRelativeNamed() {
        let root = URL(fileURLWithPath: "/tmp/root", isDirectory: true)
        let package = PackageLayout.packageURL(root: root, id: "abc")
        XCTAssertEqual(package.lastPathComponent, "abc.soundview")
        XCTAssertEqual(package.deletingLastPathComponent().lastPathComponent, "Packages")
    }
}
