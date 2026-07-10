# SoundView Product Spec (v2)

## One-liner

**One song in. Every stem out.**  
Music-first, on-device stem separator. Import or record → separate → mix → export.  
Multiplatform SwiftUI: iPhone stack · iPad/Mac **stem desk**.

## Verbs

Primary: **Import · Separate · Mix · Export**  
Secondary: **Record · Trim** (per-stem, long-press / `T`)

## Product decisions (locked)

| Topic | Decision |
|-------|----------|
| Export formats | **Both** — **WAV default** (quality), **M4A** optional (smaller) |
| Auto-separate | **Yes on import** (backgroundable, cancellable) |
| After record | Auto-separate (same pipeline) |
| Stem count UX | Show **possibility**; make **4 and 6 = better quality** obvious |
| Default mode | **4 stems** (recommended) |
| Modes | **2 / 4 / 6 / Max** with quality meter + Recommended on 4 (and strong quality on 6) |
| Max song length | Soft warnings only until measured; no hard product max yet |
| Model class | HTDemucs / Demucs v4 family (Core ML primary on iOS; MLX optional on Mac) |
| Smart reduction | **Not silent.** User chooses mode; Max shows all model outputs; weak lanes may tag “Low energy” but stay visible |
| Mac sidebar stems | **Yes** — list stems of open song for **jump**; **no reorder** |
| iPad Recorder | **Slide-over** (library stays visible) |
| Storage copy | Human-only (“Synced with iCloud” / “SoundView in iCloud Drive” / “On this iPhone|Mac”) — never raw paths |

### Stem mode quality copy

> **4 or 6 stems give the cleanest separation.**  
> More stems can isolate extra parts, but bleed and artifacts increase.

| Mode | Intent |
|------|--------|
| 2 | Faster, simpler mix |
| **4** | Best quality ★ Recommended (HTDemucs classic) |
| **6** | More detail, still strong quality |
| Max | Everything possible — quality not guaranteed |

## Screens

### Compact (iPhone)

1. **Library** — Import (primary) + Record (secondary); stem-count badges  
2. **Separation** — materializing lanes, honest ETA, backgroundable  
3. **Stem View** — stacked lanes, shared timeline, M/S/vol  
4. **Recorder** — sheet (phone)  
5. **Trim** — in-place per stem  

### Regular / Large (iPad · Mac)

- `NavigationSplitView`: **LibrarySidebar** + **StemDesk**  
- Lanes: fixed **header column** (name, vol, M/S) + wave canvas  
- Needle fixed at center of **wave area**  
- Portrait / narrow → compact stack automatically  
- Mac: menu bar, keyboard map, multi-window (`⌘N`), drag-out stems, drop-in import  
- Sidebar lists open song’s stems (jump only, no reorder)  
- iPad: Recorder as **slide-over**  

## Architecture (services)

```
FileStore          — song packages (.soundview: original + stems + mix.json)
StemSeparator      — Core ML / MLX, chunked OLA, AsyncStream<StemEvent>
StemReducer        — optional energy tags (never auto-delete user-visible stems for Max)
StemMixer          — AVAudioEngine, N sample-locked players
WaveformService    — per-stem tiles, shared viewport
AudioEngine        — record + session (v1 recorder behavior)
```

### Package layout (iCloud-friendly)

Packages prefer the **iCloud ubiquity container** `Documents/` so they appear as
**SoundView in iCloud Drive**. If iCloud is off/unavailable, fall back to
Application Support (copy: **On this iPhone** / **On this Mac**). UI never shows paths.

```
{root}/
  Packages/
    {uuid}.soundview/
      manifest.json      # ids, duration, stem mode, relative file names only
      original.{ext}     # imported or recorded master
      mix.json           # gains / mute / solo
      stems/
        00-vocals.wav
        …
```

- Imports write to `{uuid}.soundview.importing`, then **atomic rename** to `.soundview`.
- All I/O uses **NSFileCoordinator**; ubiquitous items trigger download when listed.
- Manifest stores **relative** names only — portable across devices.

## Test fixture

| Asset | Path | Spec |
|-------|------|------|
| `Test.mp3` | `Fixtures/Audio/Test.mp3` | ~308.7 s · stereo · 44.1 kHz · **MP3 open-only** |

Canonical track for import, decode, peak, viewport, and (later) separation experiments.  
Shared by unit/UI test targets via XcodeGen resources — **not** in the app target.

## Out of scope (MVP+)

- Cloud separation  
- Full DAW (fades, plugins, multi-track arrange beyond stems)  
- UIKit  

## Monetization (direction)

Freemium on stem modes / export depth — never claim Max is higher quality than 4/6.
