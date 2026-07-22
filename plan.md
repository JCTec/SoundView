# Engine — Meta Demucs (`htdemucs_ft`), on-device

## Goal

Make Meta AI Research's **official Demucs** (`htdemucs_ft`) SoundView's **sole**
separation engine: best open-source quality, 100% on-device offline inference,
modern SwiftUI + Swift 6, iOS 17+.

This supersedes every earlier engine (Spleeter, then a royalty-free BS-RoFormer
build). Those are removed from the codebase; the pipeline scaffolding they shared
(backend protocol, OLA streamer, streaming WAV writer, catalog shape) stays.

## Owner decisions (2026-07-21)

| Decision | Choice |
|----------|--------|
| Model | **Meta `htdemucs_ft`** — Hybrid Transformer Demucs, fine-tuned (best quality) |
| Delivery | **Bundle all four models** — fully offline from first launch |
| Engine lineup | **Demucs only** — no Spleeter, no BS-RoFormer |
| Licensing | Open-source, non-commercial. Demucs code MIT; weights CC-BY-NC (not App Store) |

## Architecture

```
Import/Record
    → StemSeparator
        → CoreMLDemucsBackend            // sole production engine
            → AudioFileIO (mp3/wav/m4a → 44.1k stereo)
            → per 7.8s chunk:
                DemucsSpec.forward (vDSP STFT → complex-as-channels)
                × 4 Core ML models (one per stem, owned-source select)
                iSTFT(spec_stem) + wave_stem                 // hybrid branches
            → StemAssembly (OverlapAddStreamer + WAVStreamWriter)
            → package stems/ + energy tags
```

`htdemucs_ft` is a `BagOfModels` of four fine-tuned `HTDemucs` nets with identity
mixing weights → **source *i* comes from model *i***. We export all four and take
each model's owned stem.

## Why the STFT is externalized

Core ML cannot convert torch's complex STFT/iSTFT. So the transform runs in Swift
(`Math/DemucsSpec.swift`) and the traced model sees only real tensors. Two further
op workarounds (disable the MHA fastpath; keep `view_as_complex` out of the graph)
made the transformer convertible. Full account + parity table: `docs/COREML.md`.

## Done

1. ✅ `tools/convert_htdemucs.py` — exports the four fine-tuned models + manifest.
2. ✅ Parity gate: decomposition ≥117 dB vs Meta's forward; end-to-end fp16 stem ≥25 dB.
3. ✅ `CoreMLDemucsBackend` + `DemucsManifest` wired as the single studio engine.
4. ✅ Import any song → 4 stems, chunk OLA, constant memory for long tracks.
5. ✅ Build green, unit + E2E tests green (E2E runs a real separation), SwiftLint clean.
6. ✅ Spleeter / BS-RoFormer removed; Meta/Demucs attribution in About + docs.

See `MISSION.md` for the execution contract and `docs/RELEASE.md` for the checklist.
