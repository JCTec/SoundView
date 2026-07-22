# Coding Conventions

Style inspired by **Paul Hudson / Hacking with Swift**: readable Swift, small types, modern concurrency, SwiftUI-first.

## Project layout

```
/
├── SoundView/                 # App target
│   ├── App/
│   ├── DesignSystem/          # Tokens + components (build first)
│   ├── Features/
│   ├── Services/
│   ├── Math/
│   └── Support/
├── SoundViewTests/            # Unit + integration
├── SoundViewUITests/          # Robots (1:1 views)
├── Fixtures/                  # Shared test assets only
│   └── Audio/Test.mp3
├── docs/
│   ├── *.md
│   └── design/                # Design PDFs
└── project.yml
```

## ViewModels (required pattern)

File: `LibraryView+ViewModel.swift`

```swift
import Foundation
import Observation

extension LibraryView {
    @Observable
    @MainActor
    final class ViewModel {
        private(set) var songs: [SongPackage] = []

        private let fileStore: FileStoreProtocol

        init(fileStore: FileStoreProtocol) {
            self.fileStore = fileStore
        }

        func load() async { … }
    }
}
```

Usage:

```swift
struct LibraryView: View {
    @State private var viewModel: ViewModel

    init(fileStore: FileStoreProtocol) {
        _viewModel = State(initialValue: ViewModel(fileStore: fileStore))
    }

    var body: some View { … }
}
```

- Never use free-standing `LibraryViewModel` types.
- Inject services via `init` / environment — **no singletons**.
- Keep VMs testable with protocol mocks.

## Views

- Prefer `struct` + composition.
- Subviews used **only** by one screen: nest as `private struct` in the same file, or `ViewName+Subviews.swift`.
- Target ~150 lines per view file; split by extension when growing.
- Always provide `#Preview` with mocks.
- Accessibility: `.accessibilityIdentifier(A11yID.…)` on every interactive control.

## Extensions

Prefer extensions for:

- Protocol conformances  
- Feature-scoped API on system types (e.g. `TimeInterval.asTimecode`)  
- File-private helpers grouped by concern  

## Services

- Named as nouns: `FileStore`, `StemMixer`, `WaveformService`.
- Protocol in `Services/Protocols/` or same file as `protocol FileStoreProtocol`.
- Prefer `actor` for mutable shared state / audio / file coordination.
- Emit `AsyncStream` for progress (separation, meters, file changes).
- **No Combine** for new code; async/await only.

## Math & efficiency

- Pure functions in `Math/` — no SwiftUI, no side effects.
- Document formulas in `docs/MATH.md` + `///` on public API.
- Prefer:
  - Higher-order functions (`map`, `compactMap`, `reduce`, `zip`) when clear
  - `Accelerate` / `vDSP` for bulk sample work
  - Chunked processing + overlap-add for long audio
- Never recompute full-song peaks on the main actor; stream tiles.

## Dependencies

- Prefer **SPM**.
- App project generated with **XcodeGen** (`project.yml`).
- Run **SwiftLint** in CI / pre-commit; fix warnings, not disable casually.

## Testing

### Unit

- Math: exhaustive edge cases (0, EOF, empty, 1-sample).
- ViewModels: mock services.
- Naming: `TypeNameTests.swift`.

### UI — Robot Pattern (1:1)

| View | Robot |
|------|-------|
| `LibraryView` | `LibraryViewRobot` |
| `StemDeskView` | `StemDeskViewRobot` |
| … | … |

```swift
struct LibraryViewRobot {
    let app: XCUIApplication

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Self { … }

    @discardableResult
    func tapImport() -> Self { … }
}
```

- Robots return `Self` for chaining.
- IDs live in `Support/A11yID.swift` (app) and are mirrored for UI tests.
- Flows: robot methods only — no raw `app.buttons["x"]` in test bodies.

## Multiplatform

```swift
#if os(macOS)
// menu, NSSavePanel wrappers behind protocols if needed
#endif
```

- Prefer SwiftUI APIs that work on both; size-class / `horizontalSizeClass` for layout.
- One target: iOS + macOS destinations.

## Forbidden

- UIKit UI (`UIViewRepresentable` only if Apple forces a gap — avoid). Non-UI leaf
  lookups (`DeviceKind`) are the sanctioned exception.
- Force-unwraps outside tests.  
- Magic numbers for colors/spacing/animation outside DesignSystem (amendment A3).  
- `Canvas` or stock `Slider` inside `Features/` — those belong to DesignSystem organisms.  
- Debug labels as plain text — `#if DEBUG` + `SVDebugBadge` only (amendment A4).  
- Timer-driven playheads — extrapolate `PlaybackClock` inside `TimelineView` instead.  
- Duplicated view `@State` mirroring model state — bind to the model, one source of truth.  
- God files / “Utils” grab-bags.  
- Reordering stems in sidebar (product: jump only).  

## Shared player

`StemPlayerModel` (Features/Stems) is the single source of truth for lanes, mix,
transport clock, and the shared viewport. Both layouts (`StemView`, `StemDeskView`)
compose it; wave gestures come from `.waveTimelineGestures(_:)` — never hand-rolled.
