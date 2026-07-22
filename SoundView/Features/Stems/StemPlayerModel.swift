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
    var waveform: WaveformTiers
}

/// The one player for a song: lanes, mix state, transport clock, and the shared
/// viewport (design v2 "StemPlayerVM / SharedViewport"). Both the iPhone stack and
/// the iPad/Mac desk read this same object — one drag moves every wave.
@Observable
@MainActor
final class StemPlayerModel {
    // MARK: - State

    private(set) var lanes: [StemLaneState] = []
    private(set) var clock: PlaybackClock = .zero
    private(set) var mediaDuration: TimeInterval = 0
    private(set) var loadError: String?

    /// Zoom: seconds of audio across the wave canvas. Default 12s (amendment A1 —
    /// never whole-song-smeared). Pinch clamps to 2s…120s.
    /// Note: `@Observable` forbids `Self.` in stored-property initializers.
    private(set) var visibleDuration: TimeInterval = StemPlayerModel.defaultWindow
    /// Follow mode: needle pinned at the left anchor, content scrolls beneath.
    private(set) var isFollowing = true
    /// Window start while manually panned (follow disengaged).
    private(set) var pannedStart: TimeInterval = 0

    static let defaultWindow: TimeInterval = 12
    static let zoomRange: ClosedRange<TimeInterval> = 2...120

    private var mixer: (any StemMixing)?
    private var endWatchdog: Task<Void, Never>?
    private var panOrigin: TimeInterval?
    private var zoomOrigin: TimeInterval?

    var isPlaying: Bool { clock.isPlaying }
    var anySolo: Bool { lanes.contains(where: \.isSoloed) }

    // MARK: - Loading

    func load(song: SongPackage, mixer: any StemMixing, fileStore: any FileStoreProtocol) async {
        self.mixer = mixer
        mediaDuration = song.duration
        visibleDuration = min(Self.defaultWindow, max(2, song.duration))
        lanes = song.stems.map { stem in
            StemLaneState(
                id: stem.id, name: stem.name, index: stem.index,
                volume: 1, isMuted: false, isSoloed: false,
                isLowEnergy: stem.isLowEnergy, waveform: .empty
            )
        }
        do {
            let stems = try await fileStore.stemAudioURLs(id: song.id)
            try await mixer.loadStems(stems, duration: song.duration)
            await mixer.setGains(effectiveGains)
            clock = await mixer.playbackClock()
            await loadWaveforms(for: stems)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// All stems decode in parallel off the main actor; each lane's wave fades in
    /// the moment its pyramid is ready (disk-cached, so reopen is instant).
    private func loadWaveforms(for stems: [(id: String, url: URL)]) async {
        await withTaskGroup(of: (String, WaveformTiers?).self) { group in
            for stem in stems {
                let url = stem.url
                let id = stem.id
                group.addTask(priority: .userInitiated) {
                    (id, try? WaveformTiers.loadCached(from: url))
                }
            }
            for await (id, tiers) in group {
                guard let tiers, let index = lanes.firstIndex(where: { $0.id == id }) else { continue }
                lanes[index].waveform = tiers
            }
        }
    }

    func teardown() {
        endWatchdog?.cancel()
        let mixer = self.mixer
        clock = .paused(at: clock.time(at: Date()), duration: mediaDuration)
        Task { await mixer?.setPlaying(false) }
    }

    // MARK: - Transport

    func togglePlay() {
        let target = !isPlaying
        if target { isFollowing = true }
        Task {
            await mixer?.setPlaying(target)
            clock = await mixer?.playbackClock() ?? clock
            if target {
                startEndWatchdog()
            } else {
                endWatchdog?.cancel()
            }
        }
    }

    func skip(by delta: TimeInterval) {
        seek(to: clock.time(at: Date()) + delta)
    }

    func seek(to time: TimeInterval) {
        let clamped = min(max(0, time), mediaDuration)
        // Optimistic local anchor so the needle answers on this frame.
        clock = clock.seeking(to: clamped)
        Task {
            await mixer?.seek(to: clamped)
            clock = await mixer?.playbackClock() ?? clock
        }
    }

    // MARK: - Viewport (amendment A1 — left-anchored follow)

    func visibleRange(at date: Date) -> ViewportMath.Range {
        if isFollowing {
            return ViewportMath.followRange(
                playhead: clock.time(at: date),
                visibleDuration: visibleDuration
            )
        }
        return ViewportMath.Range(start: pannedStart, end: pannedStart + visibleDuration)
    }

    func needleX(at date: Date, width: CGFloat) -> CGFloat {
        if isFollowing {
            return ViewportMath.followNeedleX(
                playhead: clock.time(at: date),
                visibleDuration: visibleDuration,
                width: width
            )
        }
        return ViewportMath.timeToX(
            time: clock.time(at: date),
            visible: visibleRange(at: date),
            width: width
        )
    }

    /// Horizontal drag: one drag scrolls all waves; disengages follow.
    func panBegan(at date: Date) {
        if panOrigin == nil {
            panOrigin = visibleRange(at: date).start
            isFollowing = false
        }
    }

    func panChanged(translationX: CGFloat, width: CGFloat, at date: Date) {
        guard let origin = panOrigin, width > 0 else { return }
        let delta = -Double(translationX / width) * visibleDuration
        pannedStart = ViewportMath.clampedPanStart(
            origin + delta,
            visibleDuration: visibleDuration,
            mediaDuration: mediaDuration
        )
    }

    func panEnded() {
        panOrigin = nil
    }

    /// Pinch zoom about the pinch centroid; all lanes zoom in sync.
    func zoomBegan() {
        if zoomOrigin == nil {
            zoomOrigin = visibleDuration
        }
    }

    func zoomChanged(magnification: CGFloat, centroidFraction: Double, at date: Date) {
        guard let origin = zoomOrigin, magnification > 0 else { return }
        let anchorTime = visibleRange(at: date).start + centroidFraction * visibleDuration
        let next = min(
            max(origin / Double(magnification), Self.zoomRange.lowerBound),
            min(Self.zoomRange.upperBound, max(2, mediaDuration))
        )
        visibleDuration = next
        if !isFollowing {
            pannedStart = ViewportMath.clampedPanStart(
                anchorTime - centroidFraction * next,
                visibleDuration: next,
                mediaDuration: mediaDuration
            )
        }
    }

    func zoomEnded() {
        zoomOrigin = nil
    }

    /// Tap the wave to seek all lanes (design §03, default-state card).
    func tapSeek(fractionOfWidth: Double, at date: Date) {
        let range = visibleRange(at: date)
        let time = range.start + fractionOfWidth * range.duration
        seek(to: time)
    }

    /// The "Return to playhead" chip re-engages follow.
    func returnToPlayhead() {
        isFollowing = true
    }

    /// Chip shows whenever the user has scrolled away from follow mode.
    var showsReturnChip: Bool { !isFollowing }

    // MARK: - Mix

    var effectiveGains: [Float] {
        MixMatrix.effectiveGains(
            lanes: lanes.map {
                MixMatrix.Lane(volume: $0.volume, isMuted: $0.isMuted, isSoloed: $0.isSoloed)
            }
        )
    }

    func toggleMute(id: String) {
        guard let index = lanes.firstIndex(where: { $0.id == id }) else { return }
        lanes[index].isMuted.toggle()
        pushGains()
    }

    func toggleSolo(id: String) {
        guard let index = lanes.firstIndex(where: { $0.id == id }) else { return }
        lanes[index].isSoloed.toggle()
        pushGains()
    }

    func setVolume(id: String, volume: Float) {
        guard let index = lanes.firstIndex(where: { $0.id == id }) else { return }
        lanes[index].volume = volume
        pushGains()
    }

    // MARK: - Private

    private func pushGains() {
        let gains = effectiveGains
        Task { await mixer?.setGains(gains) }
    }

    /// Lightweight end-of-song detection; the per-frame clock stays pure.
    private func startEndWatchdog() {
        endWatchdog?.cancel()
        endWatchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                if self.clock.hasEnded(at: Date()) {
                    await self.mixer?.setPlaying(false)
                    self.clock = .paused(at: self.mediaDuration, duration: self.mediaDuration)
                    return
                }
                if !self.isPlaying { return }
            }
        }
    }
}
