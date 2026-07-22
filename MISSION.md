# MISSION — Meta Demucs engine (on-device)

You are an autonomous agent working in this repo on a Mac with Xcode, simulators,
and network access. SoundView's **only** separation engine is Meta AI Research's
**official Demucs** (`htdemucs_ft`), converted to Core ML and bundled for offline
on-device inference at maximum open-source quality.

Owner plan: `plan.md`. Owner decisions (2026-07-21):

| Decision | Choice |
|----------|--------|
| Model | **Meta `htdemucs_ft`** — Hybrid Transformer Demucs, fine-tuned |
| Delivery | **Bundle all four models** (fully offline from install) |
| Engine lineup | **Demucs only** — Spleeter and BS-RoFormer removed |
| Licensing | Open-source, non-commercial: Demucs code MIT, weights CC-BY-NC. Not App Store. |

## Read first, in order

1. `AGENTS.md` — SwiftUI-only, design-system-first, robots.
2. `docs/CONVENTIONS.md` + `docs/DESIGN_SYSTEM.md`.
3. `docs/COREML.md` — Demucs → Core ML conversion contract (how + parity).
4. Vertical slice: `StemSeparator.swift` → `CoreMLDemucsBackend.swift` →
   `Math/DemucsSpec.swift` → `StemAssembly.swift` → `OverlapAddStreamer.swift`.

## Operating discipline

- Two loops: mechanical (build/lint/test) vs judgment (docs/PDFs decide).
- `xcodegen generate` after file add/delete; green build before next unit.
- Append WORKLOG after every milestone.
- Don't touch playback (`StemMixer`, `PlaybackClock`, viewport).

## Hard guardrails

- ✅ Demucs is the engine. Code is MIT © Meta; weights CC-BY-NC → open-source,
  non-commercial use only. State this honestly in About + docs.
- ❌ Never claim App Store / commercial distribution with the bundled NC weights.
- ❌ No hardcoded STFT/segment constants from memory — **generated manifest only**
  (`htdemucs_manifest.json`).
- ❌ No new *runtime* dependencies. `tools/` Python never ships. No Python on device.
- ✅ Attribution: Demucs (Meta) + the Défossez paper in About.

## How the engine works (see docs/COREML.md)

- `tools/convert_htdemucs.py` traces the four fine-tuned nets with the STFT/iSTFT
  externalized (Core ML can't convert torch's complex ops) and emits fp16 Core ML
  models + a manifest.
- Per 7.8 s chunk the app runs vDSP STFT → four models → `iSTFT(spec_stem) +
  wave_stem` per owned stem → Hann OLA. Constant memory for any song length.
- Parity: decomposition ≥117 dB vs Meta's forward; end-to-end fp16 stem ≥25 dB.

## Stop and ask the owner

- Signing / App Store Connect (note: NC weights preclude App Store).
- Any license bend or commercial-distribution intent.
- Reintroducing a second engine.

## Definition of done — met

Bundled `htdemucs_ft` Core ML separates offline; chunk OLA; long tracks stream;
single engine; unit + E2E tests green; SwiftLint clean; Demucs credits in About;
WORKLOG current.
