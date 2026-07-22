# SoundView

Multiplatform **SwiftUI** stem separator — iPhone · iPad · Mac.  
*One song in. Every stem out.*

[![CI](https://github.com/JCTec/SoundView/actions/workflows/ci.yml/badge.svg)](https://github.com/JCTec/SoundView/actions/workflows/ci.yml)
[![Code: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![Models: CC--BY--NC](https://img.shields.io/badge/models-CC--BY--NC%204.0-lightgrey.svg)](NOTICE.md)
![Platforms](https://img.shields.io/badge/platforms-iOS%2017%20%C2%B7%20macOS%2014-black.svg)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)
![On-device](https://img.shields.io/badge/inference-100%25%20on--device-success.svg)

## Layout

```
SoundView/                 # App sources (SwiftUI only)
SoundViewTests/            # Unit + integration tests
SoundViewUITests/          # Robot-pattern UI tests
Fixtures/                  # Shared test assets (not in app)
docs/                      # Product, conventions, math, design system
project.yml                # XcodeGen
plan.md                    # Path 4 engine plan (owner-locked decisions)
MISSION.md                 # Active execution contract
tools/convert_htdemucs.py  # Meta Demucs → Core ML converter (build-time only)
```

## Separation engine

SoundView runs Meta AI Research's **official Demucs** (`htdemucs_ft` — Hybrid
Transformer Demucs, fine-tuned) fully **on-device**. The four fine-tuned models are
converted to Core ML by `tools/convert_htdemucs.py` and bundled; there is no cloud,
no account, and no Python at runtime. Getting a complex-valued transformer through
coremltools took an externalized-STFT boundary (vDSP) plus a few op workarounds —
the whole story, with parity numbers, is in [docs/COREML.md](docs/COREML.md).

> Demucs source: MIT © Meta Platforms. `htdemucs_ft` weights: CC-BY-NC 4.0
> (research / personal). SoundView is a free, open-source, non-commercial project
> and bundles them on that basis — not distributed commercially or on the App Store.

## Docs

| Document | Contents |
|----------|----------|
| [docs/PRODUCT.md](docs/PRODUCT.md) | Product decisions |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md) | Coding standards |
| [docs/MATH.md](docs/MATH.md) | Core math |
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Tokens & components |
| [docs/COREML.md](docs/COREML.md) | On-device Meta Demucs → Core ML conversion |
| [plan.md](plan.md) | Engine plan |
| [AGENTS.md](AGENTS.md) | Agent / contributor entry |

## Principles

- **DesignSystem first** — screens consume `Color.sv.*` / `SV*` components only  
- **SwiftUI only** — no UIKit  
- **ViewModels:** `ViewName+ViewModel.swift` → `extension ViewName { class ViewModel }`  
- **Robot Pattern:** 1:1 `ViewName` ↔ `ViewNameRobot`  
- **SPM** for packages; **XcodeGen** for the app project  
- **SwiftLint** clean  
- Pure **Math/** with unit tests; Accelerate/vDSP where it matters  

## Get started

```bash
git clone https://github.com/JCTec/SoundView.git
cd SoundView
make bootstrap     # fetch the Demucs models (GitHub Releases) + generate the project
make open          # open in Xcode
make test          # unit + integration suite
```

`make help` lists every target. The Xcode project is **generated** from
`project.yml` (XcodeGen) — never edit it by hand.

### The models (~412 MB) aren't in git

Meta's Demucs weights are CC-BY-NC, so they live on **GitHub Releases**, not in the
repo. `make models` downloads them into `SoundView/Resources/`; or regenerate them
from Meta's official checkpoint with `python tools/convert_htdemucs.py` (see
[docs/COREML.md](docs/COREML.md)). The app builds fine without them — the separation
E2E test just skips.

## CI / CD

- **`ci.yml`** — every push & PR on a macOS runner: XcodeGen → SwiftLint → build →
  unit/integration tests (badge above).
- **`release-models.yml`** — manual dispatch: regenerates the four Core ML models
  from Meta's checkpoint and publishes them as a Release asset.
- Dependabot keeps the Actions + Python tooling current; issues/PRs use templates;
  `CODEOWNERS` routes review.

## Status (honest)

| Ready | Notes |
|-------|--------|
| Design system + multiplatform shell | iPhone + iPad desk |
| Math + unit tests | Viewport, OLA, peaks, energy, mix matrix |
| **FileStore** | Real `.soundview` packages |
| **Stem mixer** | Multi-lane play / mute / solo / volume |
| **Export pipeline** | Mix / stems zip / picked, WAV·M4A |
| **Separation engine** | Meta **Demucs** `htdemucs_ft`, 4 models → Core ML, on-device |
| **Parity-proven conversion** | Externalized-STFT boundary ≥117 dB vs Meta's forward; E2E stem ≥25 dB fp16 |

| Not ready |
|-----------|
| App icon artwork (owner) |

**How to separate:** Import → Separate → play / mute / solo → Export. Audio never
leaves the device.
