# Core Mathematical Features

Pure, efficient implementations live in `SoundView/Math/`.  
Goals: **correct · documented · vectorized · testable**.

Use **higher-order functions** for clarity on small collections; **Accelerate/vDSP** for sample arrays.

---

## 1. Time ↔ pixel mapping (shared viewport)

All lanes share one timeline. The playhead is fixed at the **center of the wave area** (not the window). The wave content scrolls under the needle.

### State

| Symbol | Meaning |
|--------|---------|
| \(T\) | Song duration (seconds) |
| \(t\) | Playhead time (seconds) ∈ \([0, T]\) |
| \(z\) | Zoom scale (seconds visible half-width inverse), clamped e.g. \(0.25×…50×\) relative to base |
| \(W\) | Wave canvas width (points) |
| \(H_c\) | Fixed header column width (desk layout); \(0\) on iPhone inline |

### Visible window

Let the visible duration at zoom \(z\) be:

\[
D_{\text{vis}} = \frac{D_{\text{base}}}{z}
\]

With playhead fixed at center, visible range:

\[
t_{\text{start}} = t - \frac{D_{\text{vis}}}{2},\quad
t_{\text{end}} = t + \frac{D_{\text{vis}}}{2}
\]

Clamp padding outside \([0,T]\) with empty canvas (or soft edge).

### Mappings

```text
time → x:   x = (time - t_start) / D_vis * W
x → time:   time = t_start + (x / W) * D_vis
```

Pinch zoom anchors at centroid time \(t_c\); after scale change, adjust \(t\) so \(t_c\) stays under the same pixel (standard scroll-zoom invariant).

**Impl:** `ViewportMath.swift` — `timeToX`, `xToTime`, `visibleRange`, `zoomed(around:factor:)`.

---

## 2. Waveform peak decimation (min/max tiles)

Drawing every sample is impossible for hour-long audio. We **bucket** samples and store min/max per bucket (classic peak waveform).

Given mono (or mid) samples \(s[0…N)\), bucket count \(B\):

\[
\text{for } b \in [0,B):\quad
\begin{aligned}
i_0 &= \lfloor b \cdot N / B \rfloor \\
i_1 &= \lfloor (b+1) \cdot N / B \rfloor \\
p_b &= (\min s[i_0…i_1),\; \max s[i_0…i_1))
\end{aligned}
\]

### Efficiency

- Prefer **vDSP** reduce in chunks; multi-tier pyramid (1×, 4×, 16×… buckets per second) for zoom.
- Tile cache keyed by `(stemID, tier, tileIndex)`.
- Main thread only draws visible tiles.

**Impl:** `PeakDecimation.swift` — `func minMaxPeaks(samples:bucketCount:) -> [Peak]`.

Higher-order style for small arrays:

```swift
samples.chunked(into: bucketWidth).map { chunk in
    Peak(min: chunk.min() ?? 0, max: chunk.max() ?? 0)
}
```

Large arrays: `vDSP_minv` / `vDSP_maxv` per slice.

---

## 3. Ruler “nice” ticks

At zoom level with visible duration \(D_{\text{vis}}\), choose tick step \(\delta\) from a nice set \(\{0.01, 0.05, 0.1, 0.5, 1, 2, 5, 10, 30, 60, …\}\) such that:

\[
\text{tickCount} \approx \frac{D_{\text{vis}}}{\delta} \in [4, 12]
\]

**Impl:** `NiceScale.swift` — classic “nice numbers” for time axes.

---

## 4. Overlap-add (OLA) for stem separation chunks

HTDemucs-style models process fixed-length segments (e.g. 10 s). Long songs are split with hop \(H\) and window \(W_s\) (samples).

For each chunk \(k\), model outputs stem frames \(y_k[n]\). Reconstruction:

\[
\hat{y}[n] = \frac{\sum_k w[n - kH]\, y_k[n - kH]}{\sum_k w[n - kH]}
\]

With Hann (or model-provided) window \(w\). Equal hop/window choices avoid amplitude modulation.

**Impl:** `OverlapAdd.swift` — pure accumulation buffers; used by `StemSeparator`.

Progress:

\[
p = \frac{k}{K_{\text{total}}},\quad
\text{ETA} \approx (1-p)\cdot \overline{\Delta t}_{\text{chunk}}
\]

Honest ETA = exponential moving average of chunk durations, not a fake spinner.

---

## 5. Stem energy / “low energy” tagging

Not used to hide stems in Max mode — only to **label** weak lanes.

For stem samples \(s\):

\[
E_{\text{rms}} = \sqrt{\frac{1}{N}\sum_i s_i^2}
\]

\[
E_{\text{peak}} = \max_i |s_i|
\]

Optional activity fraction: share of frames with short-time RMS above noise floor \(\varepsilon\).

Relative score vs loudest stem:

\[
c_j = \frac{E_{\text{rms},j}}{\max_k E_{\text{rms},k} + \epsilon}
\]

Tag **Low energy** if \(c_j < \tau\) (e.g. \(\tau = 0.05\)).

**Impl:** `StemEnergy.swift` — `vDSP_rmsqv` / `vDSP_maxmgv`.

---

## 6. Solo / mute mix matrix

Playback gain for lane \(i\):

```text
let anySolo = lanes.contains { $0.isSoloed }
gain_i =
  if anySolo { $0.isSoloed ? volume_i : 0 }
  else if $0.isMuted { 0 }
  else { volume_i }
```

Solo **overrides** mute for non-soloed lanes (they silence). Multiple solos combine (OR).

**Impl:** `MixMatrix.swift` — pure `func effectiveGains(lanes:) -> [Float]`.

---

## 7. Lane color (oklch-inspired)

Design: `oklch(0.78 0.11 h)` from Fern hue ~150°, step by **golden angle** \(\approx 137.508°\), skip red band (record reserved).

Approximate in sRGB for SwiftUI without full CSS oklch (MVP):

1. Generate hue sequence: \(h_n = (150 + n\cdot 137.508) \bmod 360\)  
2. If \(h_n \in [345, 20]\) (red band), skip / push forward  
3. Convert HSL/HSB with fixed S/B matched to Fern/Amber family  

Deterministic: `colorIndex(forStemIndex:)` only depends on index (+ optional song seed).

**Impl:** `LaneColorMath.swift`.

---

## 8. Trim range → CMTimeRange

Handles at times \(t_a < t_b\). Sample-accurate:

\[
\text{start} = \mathrm{CMTime}(seconds: t_a, preferredTimescale: sr)
\]

Export: passthrough `AVAssetExportSession` with `timeRange` when codec allows; else offline render.

Edge cases: clamp to \([0,T]\), minimum length \(\ge 1/sr\), swap if inverted.

**Impl:** `TrimMath.swift`.

---

## 9. Multi-player sample lock (conceptual)

One `AVAudioEngine`, \(N\) `AVAudioPlayerNode`s → mixer.

Schedule all nodes with the **same** `AVAudioTime` host time so start is sample-aligned. Seek: stop → reschedule frames at sample offset \(\lfloor t \cdot sr \rfloor\).

Drift tests: compare `player.lastRenderTime` derived positions across nodes after seek / route change.

---

## 10. Timecode formatting

Monospaced display:

| Duration | Format |
|----------|--------|
| \(< 1\) h | `m:ss.d` or `m:ss` |
| \(\ge 1\) h | `h:mm:ss` |

Pure: `TimeFormatting.swift` (Support) using integer arithmetic — avoid `DateFormatter` in hot paths.

---

## Efficiency checklist

| Path | Technique |
|------|-----------|
| Peak build | Background task, vDSP, pyramid tiers |
| Separation | Chunked inference, OLA, cancel token |
| Draw | Canvas + only visible tiles |
| Mix | Node gains, no buffer re-render for mute |
| Export | Offline graph, progress continuation |

## Testing map

| Math type | Tests |
|-----------|--------|
| `ViewportMath` | center invariants, zoom anchor, clamps |
| `PeakDecimation` | empty, 1 sample, known min/max |
| `OverlapAdd` | constant signal unity gain with Hann OLA |
| `StemEnergy` | silence, full-scale sine |
| `MixMatrix` | solo overrides, multi-solo |
| `TrimMath` | invert, zero-length, EOF |
| `NiceScale` | tick count bounds |
| `LaneColorMath` | determinism, no red band |
