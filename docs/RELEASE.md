# Release Plan — Meta Demucs engine

> **Owner decision (recorded 2026-07-21):** bundle Meta's official Demucs
> (`htdemucs_ft`, four fine-tuned models → Core ML) as the **only** separation
> engine. Fully offline, on-device. Spleeter and BS-RoFormer removed.
> Execution: `MISSION.md` · plan: `plan.md` · conversion: `docs/COREML.md`.

Goal: an open-source build with best-in-class on-device separation.

## Distribution & license

SoundView is **free, open-source, and non-commercial** — it is **not** shipped on
the App Store, because the bundled model weights are CC-BY-NC.

| Asset | License | Distribution |
|-------|---------|--------------|
| Demucs source (facebookresearch/demucs) | MIT © Meta | Conversion tooling |
| `htdemucs_ft` weights | CC-BY-NC 4.0 | **Bundled** (research / personal use) |

Because of the NC weights, do not distribute this build commercially or via the App
Store. A commercial release would require swapping in a permissively-licensed engine.

## Separation validation

- **Conversion parity** (`tools/convert_htdemucs.py --validate`): decomposition vs
  Meta's forward ≥117 dB; end-to-end fp16 Core ML stem ≥25 dB (gate). ✅
- **Swift E2E** (`SeparationE2ETests`): real separation of a clip → 4 non-zero
  stems, runtime logged. ✅ (21.6 s / 8 s clip on the simulator, CPU.)
- **Unit**: `DemucsSpec` round-trip / silence / shape. ✅

## Already release-grade (app shell)

- Playback desk, waveforms, library/import/record, export pipeline, design system,
  unit + robot tests, About credits (Demucs / Meta), privacy copy.

## Launch checklist

- [x] **Demucs Core ML models** bundled (four `.mlpackage` + manifest)
- [x] Engine wired as the single studio engine; Spleeter/BS-RoFormer removed
- [x] Conversion parity gate + Swift E2E green
- [x] About credits: Demucs (Meta), MIT code + CC-BY-NC weights, Défossez paper
- [x] Privacy: "audio never leaves this device"
- [ ] App icon artwork (owner)
- [ ] Screenshots
- [ ] On-device run on a real iPhone (measure runtime + peak RAM)

## Sequence (done)

1. ✅ Convert `htdemucs_ft` → Core ML (`tools/convert_htdemucs.py`).
2. ✅ Wire `CoreMLDemucsBackend` + `DemucsManifest`; single-engine catalog.
3. ✅ Build + unit + E2E gates green; strip Spleeter/BS-RoFormer surfaces.
4. ⏳ On-device measurement.
