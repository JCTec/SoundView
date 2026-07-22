# tools/ — build machinery, never ships

This folder is the workshop, not the product. Nothing here is compiled into,
bundled with, or executed by SoundView. The app is 100% Swift; these scripts only
produce the Core ML models + manifest that the app bundles.

| Tool | Purpose |
|------|---------|
| `convert_htdemucs.py` | Convert Meta's official **Demucs** (`htdemucs_ft`) → Core ML + manifest |

## Convert Demucs → Core ML

```bash
cd tools
python3 -m venv .venv && source .venv/bin/activate
pip install "torch" "coremltools>=8.0" "demucs" "soundfile" "numpy"

python convert_htdemucs.py --smoke                       # load the bag, print structure
python convert_htdemucs.py --only vocals                 # de-risk a single model
python convert_htdemucs.py 2>&1 | tee ../htdemucs_export.log   # export all four
python convert_htdemucs.py --validate ../Fixtures/Audio/Idilio.mp3
```

`--validate` prints, per stem, the decomposition SNR (our externalized-STFT boundary
vs Meta's official forward — expect ~120–160 dB) and the end-to-end Core ML stem SNR
(fp16, expect ~28–64 dB), gating at 25 dB on the audible waveform.

### Model (Meta, official)

`htdemucs_ft` — Hybrid Transformer Demucs, fine-tuned. A bag of four nets, one per
stem (identity mixing weights → source *i* comes from model *i*). `demucs.pretrained.get_model`
downloads the weights from Meta on first run (~320 MB, cached under `~/.cache/torch`).

| Field | Value |
|-------|-------|
| sources | drums · bass · other · vocals |
| sample rate | 44 100 Hz · stereo |
| segment | 7.8 s (343 980 samples) · nfft 4096 · hop 1024 |
| MUSDB SDR | ~9.0+ (state of the art among open models) |

### Why the STFT is externalized

Core ML can't convert torch's complex STFT/iSTFT ops (they fail on `complex64`), so
the traced core sees only real tensors: the app computes the STFT/iSTFT in vDSP
(`Math/DemucsSpec.swift`) and the model handles everything between. Two further
conversion fixes live in the script: the MHA fastpath is disabled (the fused
`_native_multi_head_attention` op is unsupported), and `_magnitude`/`_mask`/`_ispec`
are overridden so no `view_as_complex` reaches the graph. See `docs/COREML.md`.

### Output (what the app bundles)

- `SoundView/Resources/htdemucs_ft_{drums,bass,other,vocals}.mlpackage` (fp16, ~108 MB each)
- `SoundView/Resources/htdemucs_manifest.json` — the **Swift contract** (generated)

`.venv/` and downloaded checkpoints are gitignored.

### License

Demucs source: MIT © Meta Platforms. `htdemucs_ft` weights: CC-BY-NC 4.0 (research /
personal). SoundView is a free, open-source, non-commercial project and bundles them
on that basis — it is **not** distributed commercially or on the App Store.
