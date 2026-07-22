import XCTest
@testable import SoundView

final class PlaybackClockTests: XCTestCase {
    private let duration: TimeInterval = 300

    func testPausedClockHoldsPosition() {
        let clock = PlaybackClock.paused(at: 42, duration: duration)
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: Date()), 42, accuracy: 0.0001)
        XCTAssertEqual(clock.time(at: Date().addingTimeInterval(100)), 42, accuracy: 0.0001)
    }

    func testPlayingClockExtrapolates() {
        let start = Date()
        let clock = PlaybackClock.playing(from: 10, duration: duration, at: start)
        XCTAssertTrue(clock.isPlaying)
        XCTAssertEqual(clock.time(at: start.addingTimeInterval(5)), 15, accuracy: 0.0001)
        XCTAssertEqual(clock.time(at: start.addingTimeInterval(0.016)), 10.016, accuracy: 0.0001)
    }

    func testClockClampsToDuration() {
        let start = Date()
        let clock = PlaybackClock.playing(from: 295, duration: duration, at: start)
        XCTAssertEqual(clock.time(at: start.addingTimeInterval(60)), duration, accuracy: 0.0001)
        XCTAssertTrue(clock.hasEnded(at: start.addingTimeInterval(60)))
        XCTAssertFalse(clock.hasEnded(at: start))
    }

    func testClockClampsNegativeAnchors() {
        let clock = PlaybackClock.paused(at: -5, duration: duration)
        XCTAssertEqual(clock.time(at: Date()), 0, accuracy: 0.0001)
    }

    func testSeekingPreservesTransportState() {
        let playing = PlaybackClock.playing(from: 10, duration: duration)
        XCTAssertTrue(playing.seeking(to: 50).isPlaying)

        let paused = PlaybackClock.paused(at: 10, duration: duration)
        let sought = paused.seeking(to: 50)
        XCTAssertFalse(sought.isPlaying)
        XCTAssertEqual(sought.time(at: Date()), 50, accuracy: 0.0001)
    }

    func testZeroDurationNeverEnds() {
        let clock = PlaybackClock.zero
        XCTAssertFalse(clock.hasEnded(at: Date()))
        XCTAssertEqual(clock.time(at: Date()), 0, accuracy: 0.0001)
    }
}
