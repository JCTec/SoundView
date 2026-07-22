# Contributing to SoundView

Thanks for your interest! SoundView is a SwiftUI stem-separation app (iPhone · iPad
· Mac) that runs Meta's Demucs on-device. This guide gets you productive fast.

## Prerequisites

- macOS with **Xcode 16+**
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) and
  [SwiftLint](https://github.com/realm/SwiftLint): `brew install xcodegen swiftlint`
- The GitHub CLI (`gh`) if you want `make models` to pull the model weights

## Getting started

```bash
git clone https://github.com/JCTec/SoundView.git
cd SoundView
make bootstrap     # fetch the Demucs models + generate the Xcode project
make open          # open in Xcode
make test          # run the unit + integration suite
```

The project file (`SoundView.xcodeproj`) is **generated** — never edit it by hand.
Change `project.yml` and run `make generate`.

The Core ML models (~412 MB) are **not** in git. `make models` downloads them from
GitHub Releases; alternatively regenerate them with `tools/convert_htdemucs.py`
(see [`docs/COREML.md`](docs/COREML.md)). The app still builds without them — the
separation E2E test simply skips.

## House rules (see [`AGENTS.md`](AGENTS.md) + [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md))

- **SwiftUI only** — no UIKit.
- **Design system first** — screens consume `Color.sv.*` / `SV*` components only.
- **ViewModels:** `ViewName+ViewModel.swift` → `extension ViewName { class ViewModel }`.
- **Robot pattern:** one `ViewNameRobot` per screen for UI tests.
- Pure logic lives in `Math/` with unit tests; use Accelerate/vDSP where it matters.
- No hardcoded model constants — read them from the generated manifest.

## Before you open a PR

```bash
make lint          # SwiftLint clean
make test          # green
```

- Keep PRs focused; describe the change and how you verified it.
- CI (build · lint · test) must pass. It runs on every push and PR.
- By contributing you agree your changes are licensed under the repo's
  [MIT License](LICENSE).

## Reporting bugs / ideas

Use the issue templates. For security concerns, see [`SECURITY.md`](SECURITY.md).
