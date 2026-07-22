# UI Development Plan — Front-end takeover

Owner: UI agent. Scope: design fidelity, motion, and layout. Services, math, and the
separation pipeline stay untouched except where a view needs a real clock instead of a fake one.

## Verdict from the audit

The engineering skeleton is excellent (tokens, math, robots all exist), but the screens
don't consume it. Concretely:

1. **The playhead is a fake clock.** `StemDeskView.ViewModel.startPlayhead()` adds 0.05s
   every 50ms of `Task.sleep`. It drifts from the audio, steps visibly, and stops matching
   after any seek. `ViewportMath` exists but no view uses it.
2. **There is no viewport.** `StemLaneView.waveCanvas` stretches the entire song across the
   canvas width (320 buckets), needle painted at dead center, nothing scrolls, nothing zooms.
   `SharedViewport` from the design's component table was never built.
3. **Duplicated state.** `StemLaneView` and `LaneHeaderColumn` keep local `@State`
   muted/soloed/volume seeded from lane state — two sources of truth that diverge from the
   ViewModel after any external change.
4. **Missing design-system components used as stock controls**: `SVVolumeSlider`,
   `SVWaveformCanvas`, `SVTimeRuler`, `SVProgressRing` don't exist; screens use raw
   `Slider` and ad-hoc `Canvas`. `NiceScale` (ruler math) is written and unused.
5. **Layout gaps vs the Large Screens PDF**: lanes are fixed 88pt in a scroll view leaving
   dead space; no Waveform/Spectrogram pill; timecode floats top-right disconnected from
   transport; iPad transport belongs bottom-center with the timecode beside it.
6. **State hygiene**: "Separating · 95%" persists in the sidebar while the desk is already
   playable; "DEBUG · real Demucs stems" renders as plain sidebar text; "On this iPhone"
   shows on iPad.

## Product amendments (owner-approved, supersede design v2 where they conflict)

- **A1 — Left-anchored follow playhead.** The v2 PDFs pin the needle at wave-area *center*.
  Amended: the needle anchors at **20% from the left** of the wave canvas. From t=0 the
  needle travels left→anchor while content holds; at the anchor it pins and content scrolls
  right-to-left beneath it (Logic/Ableton follow mode). Manual pan disengages follow and
  shows a "Return to playhead" chip; tapping it or pressing play re-engages.
- **A2 — Separation is a full loading experience until 100%.** The separation screen owns
  the wait; when it completes, *every* loading reference disappears app-wide (no lingering
  "Separating · N%" rows). Early-listening of finished stems remains inside the separation
  screen only.
- **A3 — Spacing is a design-system concern.** No raw padding/size literals in feature
  views; everything through `SVSpacing`/`SVRadius`/`SVControlSize`. Lint-able rule.
- **A4 — Debug affordances.** Anything dev-only is (a) compiled out with `#if DEBUG`, and
  (b) visually tagged through one shared `SVDebugBadge` component — never inline strings in
  production layouts. Builders must treat any debug label without both as a bug.

## Architecture of the fix — atomic design (Brad Frost), Hacking-with-Swift style

Views stay small (one concern, computed sub-views, previews on everything), and the design
system reorganizes into explicit atomic tiers:

```
DesignSystem/
  Atoms/        Palette, Typography, Spacing, SVAnimation (new: durations/springs)
  Molecules/    SVCapsuleButton, SVTimecodeLabel, SVStemBadge, SVMuteSoloButtons,
                SVVolumeSlider (new), SVDebugBadge (new), SVProgressRing (new),
                SVWaveTogglePill (new: Waveform|Spectrogram)
  Organisms/    SVWaveformCanvas (new, viewport-driven), SVTimeRuler (new, NiceScale),
                SVTransportBar, LaneHeaderColumn, SVEmptyState, SVQualityMeter,
                SVStemModePicker, SVSyncStatusLine
  Catalog/      DesignSystemCatalog (new: one preview screen rendering every tier;
                snapshot-tested dark/light × Dynamic Type XXXL)
Features/       Templates & pages only — compose organisms, own no drawing code
```

Rule: a Feature file may not contain a `Canvas`, a `Slider`, or a color/spacing literal.
If it needs one, that's a new molecule/organism.

## Workstreams

### Phase 1 — Time, viewport, motion (the "it feels dead" fix)

- `SharedViewport` `@Observable`: playhead time, visible duration (zoom), follow state,
  interaction state. One per open song; every lane and the ruler read the same instance.
- **Real clock**: `StemMixer` exposes sample-accurate `currentTime` (AVAudioEngine
  `playerTime`); delete the 50ms incrementer. Views render via `TimelineView(.animation)`
  reading the clock per frame — continuous 60fps motion at any zoom, exact after seeks.
- Default zoom = **12s visible window** (not whole-song). Pinch zooms about the pinch
  centroid (clamp 2s–120s via `ViewportMath`); horizontal drag scrubs the shared timeline;
  tap seeks all lanes (per design §03 default-state card).
- `SVWaveformCanvas`: draws only the visible range from a **tiered peak cache**
  (`WaveformPeaks` gains ~256 / 2k / 16k-bucket tiers per stem, picked by zoom, loaded
  async). 320 buckets for a 5-minute song is why waves look like smears.
- `SVTimeRuler` above the lane stack using `NiceScale`; ticks re-space per zoom.

Acceptance: playhead never steps at 60fps; needle pins at 20%; pan disengages follow;
after 3 min of playback the needle matches audible position within 50ms.

### Phase 2 — Desk layout to spec (Large Screens PDF)

- Lanes **fill available height** (min 88, max 160pt each); vertical scroll only past ~6
  lanes. Kills the dead bottom two-thirds.
- Desk chrome: title + "N stems · M:SS" top-left; `SVWaveTogglePill` + share top-right;
  iPad transport bottom-center with the large timecode beside it; Mac transport in the top
  bar with the status strip ("6 stems · 3:51 · 48 kHz") at the bottom edge.
- Single source of truth: lane rows bind to ViewModel lane state directly; local `@State`
  copies deleted.
- Lane states per §03: mute dims lane to 35% with Amber-filled M; solo fills Fern S, tints
  lane bg, grays non-soloed lanes; multiple solos combine.
- `SVVolumeSlider`: capsule track, fat knob (design "fat volume knobs", 44pt), lane-colored.
- Verify `LaneColorMath` implements the oklch golden-angle rule skipping the red band.

### Phase 3 — States & copy hygiene

- Separation flow state machine per **A2**; kill the stale "Separating · 95%" path.
- `SVDebugBadge` + `#if DEBUG` sweep per **A4** (sidebar seed row is the first customer).
- Storage sentence becomes device-aware ("On this iPhone / iPad / Mac") — still never a path.
- iPhone `StemView` parity pass: same `SharedViewport` engine, `inline` lane layout.

### Phase 4 — Multiplatform proof & tests

- Wire the placeholder Mac menu commands + keyboard map from the PDF (Space, ⌘←/→, 1–9
  mute, ⇧1–9 solo, T trim, ⌘E export); same shortcuts drive iPad hardware keyboards.
- Snapshot matrix: iPhone, iPad portrait/landscape, Mac min/max window, dark × XXXL.
- Robots: `StemDeskRobot` gains scrub/zoom/follow assertions; unit tests for follow-anchor
  math, peak-tier selection, and clock→x mapping.

## Order & risk

Phase 1 is the highest-value, highest-risk work (touches the mixer's clock); it ships
first and alone. Phases 2–3 are pure SwiftUI and can land per-screen. Phase 4 gates release.

## Status — Phases 1–3 implemented (pending first build)

Done: `PlaybackClock` (mixer-anchored, frame-extrapolated), `ViewportMath` follow
extensions, `PeakTierMath` + `WaveformTiers` pyramid, `StemPlayerModel` (single
shared source of truth; both fake 50ms playhead timers deleted), `SVWaveformCanvas`,
`SVTimeRuler`, `SVVolumeSlider`, `SVMuteSoloButtons` (stateless), `SVDebugBadge`,
`SVReturnToPlayheadChip`, `SVAnimation`, atomic folder structure + `DesignSystemCatalog`,
desk rebuild (flexing lane heights, cross-lane needle, bottom-center transport +
live timecode, ruler), phone `StemView` on the same engine, wave gestures
(pan / pinch / tap-seek via `.waveTimelineGestures`), A2 stale-progress fix,
A4 debug sweep, device-aware storage sentence. Unit tests added for clock, follow
math, and tier selection.

Deferred to Phase 4 (unchanged): export sheet, Mac menu/keyboard map wiring,
Waveform|Spectrogram pill (needs a spectrogram service first), Mac top-bar
transport variant, snapshot matrix. Known trade-off: vertical desk scrolling with
7+ lanes must start from the header column, since wave surfaces own horizontal
drags — revisit after first hands-on session.
