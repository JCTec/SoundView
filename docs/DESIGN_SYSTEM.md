# Design System

Built **before** feature screens. Features import tokens/components only — never invent local colors.

## Brand

Dark-first field/studio aesthetic: **Pine · Fern · Amber · Signal**.

| Token | Hex | Role |
|-------|-----|------|
| `pine950` | `#0B100C` | Canvas / background |
| `pine900` | `#151C16` | Cards, fields, sidebar |
| `fern400` | `#7DC98F` | Primary / playback / positive |
| `amber400` | `#DFA75C` | Editing / attention / solo |
| `signal500` | `#E2695E` | Record **only** |
| `bone` | `#EDF1EC` | Primary text |
| `sage` | `#8FA394` | Secondary text |

Semantic aliases: `Color.sv.canvas`, `.surface`, `.accent`, `.edit`, `.record`, `.textPrimary`, `.textSecondary`.

## Type

SF Pro + Dynamic Type. Timecodes: monospaced digit.

| Style | Size / weight | Use |
|-------|---------------|-----|
| `largeTitle` | 34 / bold | Library header |
| `headline` | 17 / semibold | Row titles, lane names |
| `body` | 17 / regular | Content |
| `caption` | 13 / regular | Metadata |
| `timecode` | monospacedDigit | All times |

## Spacing & control

| Token | Value |
|-------|-------|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 24 |
| `xxl` | 32 |
| Min hit | 44 |
| Primary CTA height | 54 |
| M/S (desk) | 44 |
| Play (iPad) | 62 |
| Lane header column (desk) | ~128–160 |

Capsules everywhere. SF Symbols only.

## Components (MVP set)

| Component | Responsibility |
|-----------|----------------|
| `SVCapsuleButton` | Primary / secondary / destructive / edit |
| `SVTimecodeLabel` | Formatted time |
| `SVSyncStatusLine` | Human iCloud sentence |
| `SVStemBadge` | “N stems” Fern capsule |
| `SVEmptyState` | Icon + sentence + action |
| `SVQualityMeter` | Stem-mode quality bars |
| `SVStemModePicker` | 2 / 4 / 6 / Max + recommended |
| `SVMuteSoloButtons` | M / S pair |
| `SVVolumeSlider` | Lane volume |
| `SVWaveformCanvas` | Peak tile drawing (viewport-driven) |
| `SVTransportBar` | Play ±15s |
| `SVRecordButton` | Idle / recording / paused |
| `SVProgressRing` | Library separation progress |

## Layout modes

```swift
enum SVLaneLayout {
    case inline  // iPhone — controls in header row
    case desk    // iPad/Mac — fixed header column
}
```

## Previews

Every component: dark (default) + light, compact width, Dynamic Type XXXL sample.

## Accessibility

- AA contrast on Pine  
- Identifiers via `A11yID`  
- VoiceOver labels from product copy (human, not paths)  
