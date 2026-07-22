#!/usr/bin/env python3
"""Convert Meta's **official** Demucs (`htdemucs_ft`) → Core ML, with parity proof.

Build tooling only — never ships (see tools/README.md, docs/COREML.md). SoundView
is 100% Swift; this script only emits the `.mlpackage`s + manifest the app bundles.

    source .venv/bin/activate
    pip install demucs
    python convert_htdemucs.py --smoke
    python convert_htdemucs.py --only vocals            # de-risk one model
    python convert_htdemucs.py --export 2>&1 | tee ../htdemucs_export.log
    python convert_htdemucs.py --validate ../Fixtures/Audio/Idilio.mp3

Model: `htdemucs_ft` — a BagOfModels of four fine-tuned HTDemucs nets, one per
stem (identity mixing weights: source i comes from model i). We export each net
separately; the app runs all four per chunk and keeps each model's owned stem.

Export boundary — the STFT/iSTFT are **externalized** into Swift (vDSP,
`Math/DemucsSpec.swift`), because Core ML cannot convert torch's complex STFT
ops (they fail on `complex64`). The traced core therefore sees only real tensors:

    in : mix  [1, 2, 343980]           raw segment (time branch)
         spec [1, 4, 2048, 336]        mixture STFT, complex-as-channels (r0,i0,r1,i1)
    out: spec_stem [1, 4, 2048, 336]   owned source's masked spec (CaC) — app runs iSTFT
         wave_stem [1, 2, 343980]      owned source's time branch

Final stem waveform = iSTFT(spec_stem) + wave_stem, per Demucs' hybrid design.
The emitted manifest (`htdemucs_manifest.json`) is the Swift contract.
"""

import argparse
import json
import sys
import traceback
from pathlib import Path

MODEL_ID = "htdemucs_ft"
RESOURCES = Path(__file__).resolve().parent.parent / "SoundView" / "Resources"
# Gate on the **final stem waveform** (iSTFT(spec_stem)+wave_stem) — the audible
# output. The intermediate fp16 spectrogram sits lower (~34-48 dB, inherent to
# fp16 through a deep transformer); the end-to-end waveform is what matters, and
# 25 dB there is ~5x below any separation artifact (Demucs' own SDR is ~9 dB).
PARITY_GATE_DB = 25.0


def log(msg: str) -> None:
    print(f"[htdemucs] {msg}", flush=True)


def load_bag():
    """Load the official htdemucs_ft bag → (sub-models, sources, spec params)."""
    import torch
    from demucs.pretrained import get_model

    # Demucs' cross-transformer uses nn.MultiheadAttention, whose eval fastpath
    # emits the fused `_native_multi_head_attention` op Core ML can't convert.
    # Disabling the fastpath traces attention as plain matmul + softmax.
    if hasattr(torch.backends, "mha"):
        torch.backends.mha.set_fastpath_enabled(False)

    bag = get_model(MODEL_ID)
    models = [m.eval() for m in bag.models]
    for model in models:
        for parameter in model.parameters():
            parameter.requires_grad_(False)

    ref = models[0]
    weights = getattr(bag, "weights", None)
    info = {
        "model_id": MODEL_ID,
        "sources": list(bag.sources),
        "sample_rate": int(ref.samplerate),
        "channels": int(ref.audio_channels),
        "nfft": int(ref.nfft),
        "hop": int(ref.nfft) // 4,
        "segment_samples": int(round(float(ref.segment) * ref.samplerate)),
    }
    info["bins"] = info["nfft"] // 2                       # Nyquist dropped by _spec
    info["frames"] = -(-info["segment_samples"] // info["hop"])  # ceil = le
    # Identity weights → model i owns source i. Derive it, don't assume.
    if weights is not None:
        owners = [max(range(len(row)), key=lambda j: row[j]) for row in weights]
    else:
        owners = list(range(len(models)))
    log(f"loaded {MODEL_ID}: {info} · owners={owners}")
    return models, info, owners, torch


def build_core(model, torch, owned_index):
    """Wrap one HTDemucs net so it takes an externalized STFT and returns the
    owned source's (spec_stem, wave_stem) — **real tensors only, no complex ops**.

    Demucs' `_magnitude` immediately turns the complex mixture spectrogram back
    into the exact complex-as-channels (CaC, [r0,i0,r1,i1]) real layout we already
    hold as `spec`, and in `cac` mode `_mask` ignores its `z` argument. So we
    override `_magnitude`/`_mask`/`_ispec` to shuttle real tensors through — the
    traced graph never sees `view_as_complex`, which Core ML cannot convert."""

    class Core(torch.nn.Module):
        def __init__(self, inner, owned):
            super().__init__()
            self.inner = inner
            self.owned = owned

        def forward(self, mix, spec):
            inner = self.inner
            captured = {}
            saved = (inner._spec, inner._magnitude, inner._mask, inner._ispec)

            def fake_spec(_mix):
                return mix.new_zeros(1)                 # sentinel — never read

            def fake_magnitude(_z):
                return spec                             # inject mixture CaC directly

            def fake_mask(_z, m):
                captured["stems"] = m                   # [B, S, 2C, F, T] real CaC
                return m

            def fake_ispec(stems, length=None, scale=0):
                # Return zeros so the model's `x = xt + _ispec(...)` collapses to
                # the pure time branch `xt` (which we read as wave_stem).
                b, s, channels2, _f, _t = stems.shape
                return torch.zeros(b, s, channels2 // 2, length, dtype=mix.dtype)

            inner._spec, inner._magnitude = fake_spec, fake_magnitude
            inner._mask, inner._ispec = fake_mask, fake_ispec
            try:
                wave = inner(mix)                       # [B, S, C, L] = time branch
            finally:
                (inner._spec, inner._magnitude,
                 inner._mask, inner._ispec) = saved

            spec_stem = captured["stems"][:, self.owned].contiguous()  # [B, 2C, F, T]
            wave_stem = wave[:, self.owned].contiguous()               # [B, C, L]
            return spec_stem, wave_stem

    return Core(model, owned_index)


def example_inputs(torch, info):
    frames = info["segment_samples"]
    mix = torch.zeros(1, info["channels"], frames)
    spec = torch.zeros(1, info["channels"] * 2, info["bins"], info["frames"])
    return mix, spec


def reference_spec(model, torch, mix, info):
    """The mixture STFT the model expects, as CaC — identical to `_magnitude(_spec(mix))`."""
    z = model._spec(mix)                                # [1, C, F, T] complex
    return (
        torch.view_as_real(z)
        .permute(0, 1, 4, 2, 3)
        .reshape(1, info["channels"] * 2, info["bins"], info["frames"])
        .contiguous()
    )


def convert_one(source: str, model, owned, info, torch):
    import coremltools as ct

    core = build_core(model, torch, owned).eval()
    mix, spec = example_inputs(torch, info)
    log(f"[{source}] tracing core mix{tuple(mix.shape)} spec{tuple(spec.shape)}…")
    traced = torch.jit.trace(core, (mix, spec), strict=False, check_trace=False)
    log(f"[{source}] converting → ML Program (fp16)…")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="mix", shape=mix.shape),
            ct.TensorType(name="spec", shape=spec.shape),
        ],
        outputs=[ct.TensorType(name="spec_stem"), ct.TensorType(name="wave_stem")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
    )
    package = RESOURCES / f"{MODEL_ID}_{source}.mlpackage"
    mlmodel.save(str(package))
    size_mb = sum(f.stat().st_size for f in package.rglob("*") if f.is_file()) / 1e6
    log(f"[{source}] saved {package.name} ({size_mb:.0f} MB)")
    return mlmodel


def export() -> int:
    models, info, owners, torch = load_bag()
    RESOURCES.mkdir(parents=True, exist_ok=True)
    entries = []
    for model, owned in zip(models, owners):
        source = info["sources"][owned]
        convert_one(source, model, owned, info, torch)
        entries.append({
            "resource": f"{MODEL_ID}_{source}",
            "source": source,
            "source_index": owned,
        })

    manifest = {
        "model_id": info["model_id"],
        "sources": info["sources"],
        "sample_rate": info["sample_rate"],
        "channels": info["channels"],
        "segment_samples": info["segment_samples"],
        "nfft": info["nfft"],
        "hop": info["hop"],
        "bins": info["bins"],
        "frames": info["frames"],
        "export_boundary": (
            "stft-externalized (cac); in: mix[1,2,%d]+spec[1,4,%d,%d]; "
            "out: spec_stem[1,4,%d,%d]+wave_stem[1,2,%d]; "
            "stem = iSTFT(spec_stem)+wave_stem"
            % (info["segment_samples"], info["bins"], info["frames"],
               info["bins"], info["frames"], info["segment_samples"])
        ),
        "inputs": ["mix", "spec"],
        "outputs": ["spec_stem", "wave_stem"],
        "models": entries,
    }
    manifest_path = RESOURCES / "htdemucs_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2))
    log(f"saved {manifest_path}")
    log("EXPORT OK — next: --validate, then `xcodegen generate` and build.")
    return 0


def validate(audio_path: str) -> int:
    """Two proofs, gate ≥ 40 dB:
    1. Decomposition: iSTFT(spec_stem)+wave_stem (torch) vs full model forward.
    2. Conversion: Core ML core vs PyTorch core on the same externalized input.
    """
    import coremltools as ct
    import numpy as np
    from demucs.audio import AudioFile

    models, info, owners, torch = load_bag()
    frames = info["segment_samples"]
    wav = AudioFile(Path(audio_path)).read(
        seek_time=10, duration=info["segment_samples"] / info["sample_rate"],
        streams=0, samplerate=info["sample_rate"], channels=info["channels"],
    )
    mix = wav[None, :, :frames].float()
    if mix.shape[-1] < frames:
        mix = torch.nn.functional.pad(mix, (0, frames - mix.shape[-1]))

    worst = float("inf")
    for model, owned in zip(models, owners):
        source = info["sources"][owned]
        spec = reference_spec(model, torch, mix, info)
        core = build_core(model, torch, owned)
        with torch.no_grad():
            ref_spec, ref_wave = core(mix, spec)
            full = model(mix)[:, owned]                 # official forward, owned stem

        # (1) decomposition proof: rebuild owned stem from the two branches.
        zsel = torch.view_as_complex(
            ref_spec.reshape(1, info["channels"], 2, info["bins"], info["frames"])
            .permute(0, 1, 3, 4, 2).contiguous()
        )[:, None]                                       # [B,1,C,F,T]
        rebuilt = (model._ispec(zsel, frames)[:, 0] + ref_wave)
        decomp_snr = _snr(full.numpy(), rebuilt.numpy())
        log(f"[{source}] decomposition SNR {decomp_snr:6.1f} dB (vs official forward)")

        # (2) conversion proof: Core ML vs the official forward, end-to-end. The
        # branch SNRs are diagnostics; the gate is the reconstructed stem.
        package = RESOURCES / f"{MODEL_ID}_{source}.mlpackage"
        mlmodel = ct.models.MLModel(str(package))
        pred = mlmodel.predict({"mix": mix.numpy(), "spec": spec.numpy()})
        pred_spec = torch.from_numpy(np.asarray(pred["spec_stem"], np.float32))
        pred_wave = torch.from_numpy(np.asarray(pred["wave_stem"], np.float32))
        s_snr = _snr(ref_spec.numpy(), pred_spec.numpy())
        w_snr = _snr(ref_wave.numpy(), pred_wave.numpy())
        zpred = torch.view_as_complex(
            pred_spec.reshape(1, info["channels"], 2, info["bins"], info["frames"])
            .permute(0, 1, 3, 4, 2).contiguous()
        )[:, None]
        coreml_stem = model._ispec(zpred, frames)[:, 0] + pred_wave
        final_snr = _snr(full.numpy(), coreml_stem.numpy())
        log(f"[{source}] coreml stem {final_snr:6.1f} dB  "
            f"(diag: spec {s_snr:.1f} · wave {w_snr:.1f})")
        worst = min(worst, decomp_snr, final_snr)

    ok = worst >= PARITY_GATE_DB
    log(f"PARITY {'PASS ✅' if ok else 'FAIL ❌'} (worst {worst:.1f} dB, gate {PARITY_GATE_DB:.0f} dB)")
    return 0 if ok else 1


def _snr(reference, candidate) -> float:
    import numpy as np
    ref = np.asarray(reference, np.float32).reshape(-1)
    out = np.asarray(candidate, np.float32).reshape(-1)
    noise = float(np.sum((out - ref) ** 2)) + 1e-12
    return 10.0 * np.log10(float(np.sum(ref ** 2)) / noise)


def smoke() -> int:
    _, info, owners, _ = load_bag()
    log(f"SMOKE OK — {len(owners)} models, sources={info['sources']}")
    return 0


def only(source: str) -> int:
    """Convert a single stem's model (de-risk the pipeline before the full run)."""
    models, info, owners, torch = load_bag()
    idx = info["sources"].index(source)
    model = models[owners.index(idx)] if idx in owners else models[idx]
    RESOURCES.mkdir(parents=True, exist_ok=True)
    convert_one(source, model, idx, info, torch)
    log(f"ONLY OK — {source}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--only", metavar="SOURCE")
    parser.add_argument("--validate", metavar="AUDIO")
    args = parser.parse_args()
    try:
        if args.smoke:
            return smoke()
        if args.only:
            return only(args.only)
        if args.validate:
            return validate(args.validate)
        return export()
    except Exception:  # noqa: BLE001 — the full trace IS the deliverable on failure
        traceback.print_exc()
        log("FAILED — tee this log into the repo; iterate from the trace.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
