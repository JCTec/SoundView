import AVFoundation
import Foundation

/// Sample-locked multi-stem playback via `AVAudioEngine`.
actor StemMixer: StemMixing {
    private let engine = AVAudioEngine()
    private var players: [String: AVAudioPlayerNode] = [:]
    private var files: [String: AVAudioFile] = [:]
    private var orderedIDs: [String] = []
    private var duration: TimeInterval = 0
    private var isLoaded = false
    /// Wall-clock anchor — re-anchored on load / play / pause / seek.
    private var clock: PlaybackClock = .zero

    /// Load concrete stem file URLs (id → url), sample-locked via shared engine clock.
    func loadStems(_ stems: [(id: String, url: URL)], duration: TimeInterval) async throws {
        await stopEngine()
        players.removeAll()
        files.removeAll()
        orderedIDs = stems.map(\.id)
        self.duration = duration

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        #endif

        let mainMixer = engine.mainMixerNode
        for stem in stems {
            let file = try AVAudioFile(forReading: stem.url)
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mainMixer, format: file.processingFormat)
            players[stem.id] = player
            files[stem.id] = file
        }

        engine.prepare()
        try engine.start()
        scheduleAll(from: 0)
        isLoaded = true
        clock = .paused(at: 0, duration: duration)
    }

    /// Current transport anchor; UI extrapolates per frame — never poll.
    func playbackClock() async -> PlaybackClock {
        clock
    }

    func setPlaying(_ playing: Bool) async {
        guard isLoaded else { return }
        if playing {
            if !engine.isRunning {
                try? engine.start()
            }
            let from = clock.time(at: Date())
            for id in orderedIDs {
                players[id]?.play()
            }
            clock = .playing(from: from, duration: duration)
        } else {
            let position = clock.time(at: Date())
            for id in orderedIDs {
                players[id]?.pause()
            }
            clock = .paused(at: position, duration: duration)
        }
    }

    func seek(to time: TimeInterval) async {
        guard isLoaded else { return }
        let wasPlaying = clock.isPlaying
        for id in orderedIDs {
            players[id]?.stop()
        }
        let clamped = min(max(0, time), duration)
        scheduleAll(from: clamped)
        if wasPlaying {
            for id in orderedIDs {
                players[id]?.play()
            }
            clock = .playing(from: clamped, duration: duration)
        } else {
            clock = .paused(at: clamped, duration: duration)
        }
    }

    func setGains(_ gains: [Float]) async {
        // gains aligned with orderedIDs
        for (index, id) in orderedIDs.enumerated() {
            let gain = index < gains.count ? gains[index] : 1
            players[id]?.volume = max(0, min(1, gain))
        }
    }

    func setGain(id: String, value: Float) {
        players[id]?.volume = max(0, min(1, value))
    }

    // MARK: - Private

    private func scheduleAll(from time: TimeInterval) {
        for id in orderedIDs {
            guard let player = players[id], let file = files[id] else { continue }
            let startFrame = AVAudioFramePosition(time * file.processingFormat.sampleRate)
            let length = max(0, file.length - startFrame)
            guard length > 0 else { continue }
            player.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(length),
                at: nil,
                completionHandler: nil
            )
        }
    }

    private func stopEngine() async {
        for player in players.values {
            player.stop()
            engine.detach(player)
        }
        engine.stop()
    }
}

enum StemMixerError: Error, LocalizedError {
    case notLoaded

    var errorDescription: String? {
        "Mixer has no stems loaded."
    }
}
