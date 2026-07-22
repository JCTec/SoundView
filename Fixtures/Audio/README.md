# Audio fixtures

| File / folder | Role |
|---------------|------|
| **`Idilio.mp3`** | Development mix (~5:09). Bundled; DEBUG launch seeds into real FileStore. |
| **`Idilio-stems/`** | **Real Demucs `htdemucs_6s` stems** for Idilio: `vocals`, `drums`, `bass`, `guitar`, `piano`, `other`. |
| `Test.mp3` | Unit-test host copy (same audio as Idilio for now). |

## Regenerating stems (Python parity)

```bash
./scripts/separate_idilio.sh
```

Uses Meta’s **htdemucs_6s** — the same 6-stem family as a typical Python Demucs pass  
(bass / drums / guitar / other / piano / vocals). “Other” can still contain residual bits of several sources.

## What the app does with them

1. Library loads **Idilio** as an unseparated package (real mix file).  
2. **Separate** copies the bundled Demucs WAVs into the package (progress is real I/O + energy tagging).  
3. Stem View / Desk **play the real WAVs** via `AVAudioEngine` (mute / solo / volume).  
4. Waveforms are **real peak decimation** from those WAVs — not sine placeholders.

On-device Core ML HTDemucs (no precomputed pack) is the next backend swap; the pipeline is already shaped for it.

## Size note

Each stem is ~52 MB 16-bit stereo WAV (~5 min). Pack is local under `Fixtures/Audio/Idilio-stems/` (gitignored). Rebuild needs those files present.
