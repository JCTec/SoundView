# WORKLOG — Path 3 Dual-Model Release

The owner reads only this file to track the build. Gates appended in order.
Format per entry: **Gate** · PASS/FAIL · evidence (command + output snippet) · time.

---

## DAY 1 — Produce the Spleeter .mlpackage (tools/, gated)

Start: 2026-07-10. Host: Apple Silicon (arm64) Mac, Python 3.9.6 system,
Xcode coremlcompiler present, no tools venv yet.

Plan (per MISSION §DAY 1):
- 1.1 venv: `pip install spleeter coremltools` (TF; pin per README on conflict).
- 1.2 `tools/convert_spleeter.py` modeled on `convert_htdemucs.py` — export the
  mask U-Net only (magnitude spec in → per-stem masks out), STFT stays in Swift.
  Manifest derived from spleeter source configs, not guessed.
- Gate D1-A (export): package + manifest exist, `coremlcompiler compile` passes.
- Gate D1-B (parity): `--validate` one chunk TF↔CoreML, worst-tensor SNR ≥ 40 dB.

### 1.1 Environment — RESOLVED (mechanical loop)

`pip install spleeter` on arm64/py3.9 collapsed into resolver backtracking (numba
0.51→0.50…): Spleeter pins `tensorflow==2.12.1`, which has **no arm64 wheel**
(plain `tensorflow` starts at 2.13.0 here), so the resolver kept falling back to
ancient Spleeter releases dragging unbuildable numba. Fix (pin per README intent):
installed the Apple-Silicon build of the exact TF version Spleeter targets +
coremltools, and skipped Spleeter's runtime entirely — its **source + configs +
weights** are what's needed, not its (conflict-ridden) package.

```
tensorflow-macos==2.12.0   numpy 1.23.5   coremltools 9.0   (all import on arm64)
```

Spleeter's architecture is transcribed from its own `unet.py`; every scalar is
read from the vendored upstream config `tools/spleeter_configs/4stems.json`
(deezer/spleeter, MIT — also satisfies the repo-side attribution guardrail);
weights are Deezer's official v1.4.0 `4stems.tar.gz` (146 MB), restored **by name**
with a "every checkpoint variable consumed" assertion. Nothing guessed.

Config (from source): sources vocals/drums/bass/other · sr 44100 · n_fft 4096 ·
hop 1024 · T 512 · F 1024 · separation_exponent 2 · mask_extension zeros · ELU.

### 1.2 `tools/convert_spleeter.py` — written, mirrors convert_htdemucs.py

Boundary identical to Demucs: **magnitude spectrogram in (1,512,1024,2) → 4
per-stem masked magnitudes out**; STFT/iSTFT/soft-mask stay in Swift (Day 2).
Emits `SoundView/Resources/spleeter_manifest.json` with tensor names+shapes and a
full `masking` section (ratio soft-mask: `mask_i=(out_i²+ε/N)/(Σout_j²+ε)`,
ε=1e-10, zeros-extend 1024→2049 bins, window-compensation 2/3, prepad/crop 4096).
Core ML mangles output names to `Identity*`; the tool maps each to its instrument
by **content** (lowest MSE vs Keras ref) so the manifest order is proven, and
records `outputs`↔`output_order` accordingly.

**Two-strike note (mechanical loop, coremltools):** ① `ct.convert` couldn't infer
framework → added `source="tensorflow"`. ② naming outputs by Keras layer name
(`vocals_spectrogram is not in graph`) → dropped `outputs=` names, map by content
after. Both fixed first retry; no three-strike.

### Gate D1-A (export) · **PASS** · ~time: env+tool ~1.5h

```
$ python convert_spleeter.py
[spleeter] restored 280 tensors; all consumed except spleeter's 4 disconnected
           batch6 BN layers (expected) ✅
[spleeter] saved SoundView/Resources/spleeter_4stems.mlpackage   (75 MB, fp16)
[spleeter] output map: vocals←Identity_3 drums←Identity_1 bass←Identity other←Identity_2
[spleeter] EXPORT OK
$ xcrun coremlcompiler compile spleeter_4stems.mlpackage /tmp/sv_mlc
/tmp/sv_mlc/spleeter_4stems.mlmodelc/coremldata.bin   (exit 0)
```
Package + manifest exist; compiler check passes. ✅

### Gate D1-B (parity) · **PASS** · worst 42.0 dB ≥ 40 dB gate

```
$ python convert_spleeter.py --validate ../Fixtures/Audio/Idilio.mp3
[spleeter] vocals←'Identity_3': SNR 51.7 dB
[spleeter] drums ←'Identity_1': SNR 51.0 dB
[spleeter] bass  ←'Identity'  : SNR 48.9 dB
[spleeter] other ←'Identity_2': SNR 42.0 dB
[spleeter] PARITY PASS ✅ (worst 42.0 dB, gate 40 dB)
```
First run used a synthetic tonal probe → worst 14.6 dB, but "other" hit 52 dB:
the tones routed almost entirely to *other*, starving the other 3 stems'
references to ~0 so constant fp16 error dominated their SNR (a measurement
artifact, not a conversion defect). Switched the probe to real audio (ffmpeg
decode of Idilio, 30 s in) as the mission's `--validate` command intends — all
four stems land at 42–52 dB, cleanly fp16-tolerance. Conversion is faithful.

### Build / bundle check (end-of-day cadence)

- `xcodegen generate` → exit 0 (clean, with the new Resources present).
- `.gitignore` extended: `tools/checkpoints/` (146 MB weights) + all export/parity
  logs. `git check-ignore` confirms venv, checkpoint, logs are all excluded; only
  `SoundView/Resources/spleeter_*` is untracked (the two intended deliverables).
- `xcodebuild build -scheme SoundView` → **BUILD FAILED**, but the cause is
  **pre-existing and not Day-1 work**. Every error is:
  `coremlc: error: Model does not exist at .../htdemucs_{6s_core,core,separator_core}.mlpackage`.
  project.yml references three Demucs packages that were never placed in
  `Resources/` (the manual Tier-3 `cp` in docs/COREML.md the owner hasn't run).
  Its own comment says "Optional so the project builds before the export has been
  run" — but XcodeGen's `optional: true` still emits a CoreML-codegen ref for a
  `.mlpackage`, so the intent isn't delivered. Swift never compiles (0 files) —
  codegen gates it — so the in-progress design-system refactor's health is still
  unknown behind this blocker.
- **My work is clean of this:** no error mentions spleeter, and coremlc actually
  runs codegen on `spleeter_4stems.mlpackage` with **no error** (an extra
  Xcode-side validation the package passes). It is not yet wired into project.yml
  (that's Day-2 bundling), so it doesn't affect the build either way.

### DAY 1 — STATUS: gates D1-A ✅ and D1-B ✅ (both green, evidenced above).

Deliverables in place: `tools/convert_spleeter.py`, vendored MIT config +
license under `tools/spleeter_configs/`, `SoundView/Resources/spleeter_4stems.mlpackage`
(75 MB fp16) + `spleeter_manifest.json`. Ready for Day-2 Swift wiring.

**Close-out (owner decisions applied):**
- Commit: **scoped Day-1 commit** `95e79a0` — only Day-1 artifacts staged
  (convert_spleeter.py, vendored config+license, spleeter_4stems.mlpackage +
  manifest, WORKLOG, .gitignore). The unrelated design-system refactor stays
  uncommitted. project.yml / regenerated pbxproj deliberately NOT committed.
- Pre-existing red build: **owner will supply the Demucs model** into `Resources/`
  themselves; I did NOT modify project.yml. Day 2 is **paused** until the build is
  green (per "never start a new unit on a red build").

**Day 2 is unblocked once** a Demucs `.mlpackage` is present in `SoundView/Resources/`
(or its refs made build-optional) and `xcodebuild build -scheme SoundView` is green.
Then: Math/SpleeterSpec.swift (magnitude STFT per manifest) → SpleeterBackend →
ModelCatalog → BYO import. All contract values already live in
`spleeter_manifest.json`.


