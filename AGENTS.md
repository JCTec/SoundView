# SoundView — Agent & Contributor Guide

Multiplatform SwiftUI stem-separation app (iPhone · iPad · Mac).  
**Design system first. Swift only. No UIKit.**

## Source of truth

| Doc | Purpose |
|-----|---------|
| `docs/PRODUCT.md` | Product decisions (v2 + large screens + stem quality UX) |
| `docs/CONVENTIONS.md` | Coding standards (Hacking with Swift style) |
| `docs/MATH.md` | Core mathematical features — keep efficient & documented |
| `docs/DESIGN_SYSTEM.md` | Tokens, components, usage |
| `docs/design/*.pdf` | Phone + large-screen design PDFs |
| `Fixtures/Audio/` | Shared test media (not in app target) |

## Non-negotiables

1. **SwiftUI only** — no UIKit views/controllers.
2. **DesignSystem first** — app screens consume tokens/components; no raw hex in Features.
3. **Paul Hudson / Hacking with Swift style** — clear names, small types, `@Observable`, environment DI.
4. **SPM preferred** for dependencies; XcodeGen for the app project.
5. **SwiftLint** must stay clean.
6. **Single responsibility** — one type, one job; prefer extensions to grow types.
7. **ViewModels:** `ViewName+ViewModel.swift` with  
   `extension ViewName { @Observable final class ViewModel { … } }`
8. **Private nested views** live in the same file (or `ViewName+Subviews.swift`) when used only there.
9. **Robot Pattern UI tests:** 1:1 `ViewName` → `ViewNameRobot`.
10. **Document math** in `docs/MATH.md` and in-source doc comments; prefer higher-order / vDSP / Accelerate.

## Build

```bash
xcodegen generate
swiftlint lint --strict
# open SoundView.xcodeproj
```

## Order of work

1. DesignSystem (tokens → primitives → composites)  
2. Support math + pure services (unit-tested)  
3. Features wired to services via protocol DI  
4. Robots + UI tests per screen  
