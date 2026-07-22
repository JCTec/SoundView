# Third-party notices

SoundView separates audio with **Demucs**, by Meta AI Research.

## SoundView source code

The code in this repository is licensed under the **MIT License** (see
[`LICENSE`](LICENSE)) © 2026 Juan Carlos Estevez.

## Demucs

- **Source / architecture:** [`facebookresearch/demucs`](https://github.com/facebookresearch/demucs),
  © Meta Platforms, Inc. and affiliates — **MIT License**. Used only at build time
  by `tools/convert_htdemucs.py` to convert the model to Core ML; no Demucs code
  ships in the app.
- **Model weights (`htdemucs_ft`):** released by Meta under
  **CC-BY-NC 4.0** — *non-commercial use only*. These weights are **not** stored in
  this repository; they are downloaded from GitHub Releases (or regenerated locally)
  and bundled into the app.
- **Paper:** Alexandre Défossez, *"Hybrid Transformers for Music Source Separation,"*
  ISMIR 2023 ([arXiv:2211.08553](https://arxiv.org/abs/2211.08553)).

## What this means for use

Because the bundled model weights are CC-BY-NC:

- ✅ You may use, run, study, modify, and **share this project freely** for
  non-commercial purposes (personal use, portfolios, education, research).
- ❌ You may **not** sell it, put it behind a paywall, run it as a paid service, or
  otherwise use it commercially while it bundles the CC-BY-NC weights.

To build a commercial product, replace the engine with permissively-licensed model
weights.
