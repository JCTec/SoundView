# On-Device Separation — Meta Demucs → Core ML

SoundView separates stems with Meta AI Research's **official Demucs**
(`htdemucs_ft`), converted to Core ML and bundled so inference runs 100% on-device,
offline, with no Python and no network. This doc is the record of *how* the
conversion works — the interesting engineering is getting a complex-valued,
transformer-based PyTorch model through coremltools intact.

Converter: [`tools/convert_htdemucs.py`](../tools/convert_htdemucs.py) ·
Swift contract: `SoundView/Resources/htdemucs_manifest.json`.

## The model

`htdemucs_ft` is **Hybrid Transformer Demucs, fine-tuned** — the best-quality open
separator Meta ships. It's a `BagOfModels` of four `HTDemucs` nets, each fine-tuned
for one stem; the bag's mixing weights are the identity, so **source *i* is taken
from model *i***. We export all four and the app runs them per chunk.

| Field | Value |
|-------|-------|
| sources | drums · bass · other · vocals |
| sample rate | 44 100 Hz · stereo |
| segment | 7.8 s = 343 980 samples · nfft 4096 · hop 1024 · 336 frames · 2048 bins |
| precision | fp16 ML Program · iOS 17 deployment target |
| size | ~108 MB × 4 models |

## Export boundary — externalized STFT (the crux)

HTDemucs is a **hybrid** model: a spectral branch (STFT → conv/transformer → masked
spectrogram → iSTFT) summed with a time-domain branch. Its `forward` ends at:

```python
zout = self._mask(z, x)          # complex masked spectrogram
x    = self._ispec(zout, length) # iSTFT → waveform
xt   = xt.view(B, S, C, length)  # time branch
return xt + x
```

Core ML **cannot** convert torch's complex STFT/iSTFT — conversion dies on the first
op that touches a `complex64` tensor. So the STFT and iSTFT are lifted out of the
model and reimplemented in Swift/vDSP (`Math/DemucsSpec.swift`, exact Demucs
conventions: reflect pre-pad `3·hop/2`, torch center-pad `nfft/2`, periodic Hann,
`1/√nfft` normalization, Nyquist bin dropped). The traced core sees **only real
tensors**:

```
in : mix  [1, 2, 343980]         raw segment (time branch)
     spec [1, 4, 2048, 336]      mixture STFT, complex-as-channels (r0,i0,r1,i1)
out: spec_stem [1, 4, 2048, 336] owned source's masked spec (CaC) — app runs iSTFT
     wave_stem [1, 2, 343980]    owned source's time branch
```

The app reconstructs each stem as `iSTFT(spec_stem) + wave_stem`, then overlap-adds
7.8 s chunks (25% hop, Hann WOLA) so memory stays flat for any song length.

## Three conversion hurdles (and the fixes)

Each was found by running the converter and reading the traceback — the script
prints the full trace on failure by design.

| # | coremltools error | Fix |
|---|-------------------|-----|
| 1 | `slice … got tensor[…, complex64]` — internal STFT | **Externalize** STFT/iSTFT to vDSP; feed the mixture spectrogram as complex-as-channels. |
| 2 | `view_as_complex not implemented` — inside the wrapper | Don't rebuild the complex tensor: `_magnitude` turns it straight back to CaC and `_mask` (cac mode) ignores `z`. Override `_magnitude`/`_mask`/`_ispec` to shuttle **real** tensors through — zero complex ops in the graph. |
| 3 | `_native_multi_head_attention not implemented` — cross-transformer | `torch.backends.mha.set_fastpath_enabled(False)` so attention traces as plain matmul + softmax. |

The wrapper captures the masked spectrogram at the `_ispec` boundary and returns
zeros there, so `xt + _ispec(...)` collapses to the pure time branch — giving both
branches out separately, faithful to Meta's math.

## Parity gates (`--validate`)

Two independent proofs on a real audio chunk:

1. **Decomposition** — `iSTFT(spec_stem) + wave_stem` (torch) vs Meta's official
   `htdemucs_ft` forward. Confirms the externalized boundary is exact.
2. **Conversion** — Core ML reconstructed stem vs the official forward. The audible,
   end-to-end number; gated at **25 dB** (fp16 through a deep transformer).

Measured (Idilio.mp3, 2026-07-21):

| stem | decomposition | Core ML stem (fp16) |
|------|---------------|---------------------|
| drums | 153.7 dB | 55.1 dB |
| bass | 157.9 dB | 64.0 dB |
| other | 156.5 dB | 58.5 dB |
| vocals | 117.3 dB | 28.5 dB |

The decomposition SNRs (~120–160 dB) prove the STFT boundary reproduces Meta's
forward to numerical precision. The Core ML gap is pure fp16 quantization on the
spectral branch — 28–64 dB reconstruction error sits far below any separation
artifact (Demucs' own MUSDB SDR is ~9 dB), i.e. inaudible.

## Compute units

The GPU/MPSGraph backend faults on these converted models, and the fp16 ANE
compiler can't compile them either, so the backend requests `.cpuAndNeuralEngine`
(device) / `.cpuOnly` (simulator) and Core ML runs them on CPU. `htdemucs_ft` is
compute-heavy by design (four nets); on-device this trades speed for top quality —
the deliberate choice for an offline "studio" engine.

## Swift wiring

- `Services/Separation/CoreMLDemucsBackend.swift` — loads the four models, runs them
  per chunk, reconstructs + overlap-adds.
- `Services/Separation/DemucsManifest.swift` — decodes `htdemucs_manifest.json`
  (every shape/param comes from the manifest, never a constant from memory).
- `Math/DemucsSpec.swift` — the vDSP STFT/iSTFT (round-trip tested in
  `DemucsSpecTests`).
- `ModelCatalog` — a single studio engine; no other separators in the product path.

## License

Demucs source is MIT © Meta Platforms. The `htdemucs_ft` weights are CC-BY-NC 4.0
(research / personal use). SoundView is a free, open-source, **non-commercial**
project — not on the App Store — and bundles the weights on that basis. Attribution
lives in-app (`AboutView`) and here.
