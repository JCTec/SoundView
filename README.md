# SoundView

Multiplatform **SwiftUI** stem separator — iPhone · iPad · Mac.  
*One song in. Every stem out.*

## Layout

```
SoundView/                 # App sources (SwiftUI only)
SoundViewTests/            # Unit + integration tests
SoundViewUITests/          # Robot-pattern UI tests
Fixtures/                  # Shared test assets (not in app)
  └── Audio/Test.mp3
docs/                      # Product, conventions, math, design system
  └── design/              # Design PDFs (v2 + large screens)
project.yml                # XcodeGen
```

## Docs

| Document | Contents |
|----------|----------|
| [docs/PRODUCT.md](docs/PRODUCT.md) | Product decisions |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md) | Coding standards |
| [docs/MATH.md](docs/MATH.md) | Core math |
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Tokens & components |
| [docs/design/](docs/design/) | Design PDFs |
| [Fixtures/README.md](Fixtures/README.md) | Test media |
| [AGENTS.md](AGENTS.md) | Agent / contributor entry |

## Principles

- **DesignSystem first** — screens consume `Color.sv.*` / `SV*` components only  
- **SwiftUI only** — no UIKit  
- **ViewModels:** `ViewName+ViewModel.swift` → `extension ViewName { class ViewModel }`  
- **Robot Pattern:** 1:1 `ViewName` ↔ `ViewNameRobot`  
- **SPM** for packages; **XcodeGen** for the app project  
- **SwiftLint** clean  
- Pure **Math/** with unit tests; Accelerate/vDSP where it matters  

## Generate & open

```bash
cd /Users/jc/Dev/SoundView
xcodegen generate
open SoundView.xcodeproj
swiftlint lint
```

## Test audio

| File | Location | Notes |
|------|----------|--------|
| `Test.mp3` | [`Fixtures/Audio/Test.mp3`](Fixtures/Audio/Test.mp3) | Stereo 44.1 kHz · ~5:09 · open-only MP3 |

Unit tests: `TestFixtures.testMP3URL` (not shipped in the app).

```bash
xcodebuild -scheme SoundView -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SoundViewTests test
```

## Status

Phase: **Design system + shell + math + production FileStore**.  
Done: iCloud-friendly `.soundview` packages, import via document picker, coordinated I/O.  
Next: Core ML `StemSeparator`, real waveform tiles, mixer, export, fuller robots.
