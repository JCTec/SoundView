# Fixtures

Shared **test-only** assets. Never ship in the app target.

```
Fixtures/
└── Audio/
    └── Test.mp3    # stereo 44.1 kHz · ~5:09 · MP3 open-only path
```

| Asset | Spec | Used by |
|-------|------|---------|
| `Audio/Test.mp3` | ~308.7 s · 2 ch · 44.1 kHz | `SoundViewTests` via `TestFixtures` |

## Adding assets

1. Put files under `Fixtures/<kind>/`.
2. Wire the folder in `project.yml` as `buildPhase: resources` for the test target(s).
3. Expose URLs from `SoundViewTests/Support/TestFixtures.swift` (or a UITest helper).

Do **not** drop large media at the repo root or inside `SoundView/`.
