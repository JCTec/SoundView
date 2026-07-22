#!/usr/bin/env python3
"""Ground-truth probe: dump torch's reference_spec + full-model stems for a
deterministic stereo signal, so the Swift DemucsSpec/backend can be compared
against torch on the *exact same samples* (no mp3 decoder in the loop).

Interchange = headerless float32:
  probe_x.f32            [C, segment]           channel-major mixture (Swift input)
  probe_torch_spec.f32   [2C, bins, frames]     torch reference_spec (C-order)
  probe_torch_stems.f32  [S, C, segment]        torch full-model stems (owned)
  probe_meta.json        shapes + params
"""
import json
import sys
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent))
from convert_htdemucs import load_bag, reference_spec, build_core  # noqa: E402

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp")


def deterministic_mix(channels, segment, sr):
    n = np.arange(segment, dtype=np.float64)
    x = np.zeros((channels, segment), dtype=np.float32)
    # Distinct per-channel content: tones + a linear chirp (exercises all bins,
    # varied phase → catches real/imag swaps and bin-order errors).
    x[0] = (0.20 * np.sin(2 * np.pi * 220.0 * n / sr)
            + 0.10 * np.sin(2 * np.pi * 440.0 * n / sr + 0.7)
            + 0.08 * np.sin(2 * np.pi * (300.0 + 4000.0 * n / segment) * n / sr))
    if channels > 1:
        x[1] = (0.15 * np.sin(2 * np.pi * 330.0 * n / sr + 0.3)
                + 0.05 * np.sin(2 * np.pi * 1760.0 * n / sr)
                + 0.08 * np.sin(2 * np.pi * (8000.0 - 6000.0 * n / segment) * n / sr))
    return x


def main():
    models, info, owners, _ = load_bag()
    C, segment, sr = info["channels"], info["segment_samples"], info["sample_rate"]
    x = deterministic_mix(C, segment, sr)
    mix = torch.from_numpy(x[None]).float()  # [1, C, segment]

    spec = reference_spec(models[0], torch, mix, info)  # [1, 2C, bins, frames]

    stems = []
    with torch.no_grad():
        for model, owned in zip(models, owners):
            stems.append(model(mix)[:, owned][0].numpy())  # [C, segment]
    stems = np.stack(stems, 0).astype(np.float32)          # [S, C, segment]

    # --- Inverse ground truth (isolates iSTFT from the model) -------------
    # torch _ispec of (a) the mixture spec  and  (b) a masked spec that mimics
    # the model's spec_stem (an *invalid* STFT — where inverse conventions bite).
    def ispec_of(spec_2c):  # spec_2c: torch [1, 2C, bins, frames] -> [C, segment]
        z = torch.view_as_complex(
            spec_2c.reshape(1, C, 2, info["bins"], info["frames"])
            .permute(0, 1, 3, 4, 2).contiguous()
        )[:, None]                              # [1, 1, C, bins, frames]
        return models[0]._ispec(z, segment)[0, 0].numpy()  # [C, segment]

    ispec_ref = ispec_of(spec)
    masked = spec.clone()
    masked[:, :, info["bins"] // 2:, :] = 0.0   # zero the upper half of bins
    ispec_masked = ispec_of(masked)

    x.astype("<f4").tofile(OUT / "probe_x.f32")
    np.asarray(spec[0], np.float32).astype("<f4").tofile(OUT / "probe_torch_spec.f32")
    np.asarray(masked[0], np.float32).astype("<f4").tofile(OUT / "probe_masked_spec.f32")
    np.asarray(ispec_ref, np.float32).astype("<f4").tofile(OUT / "probe_torch_ispec_ref.f32")
    np.asarray(ispec_masked, np.float32).astype("<f4").tofile(OUT / "probe_torch_ispec_masked.f32")
    stems.astype("<f4").tofile(OUT / "probe_torch_stems.f32")
    meta = {
        "channels": C, "segment": segment, "sample_rate": sr,
        "bins": info["bins"], "frames": info["frames"],
        "sources": info["sources"], "owners": owners,
        "spec_shape": list(spec[0].shape), "stems_shape": list(stems.shape),
        "spec_rms": float(np.sqrt(np.mean(np.asarray(spec).astype(np.float64) ** 2))),
        "stems_rms": [float(np.sqrt(np.mean(s.astype(np.float64) ** 2))) for s in stems],
    }
    (OUT / "probe_meta.json").write_text(json.dumps(meta, indent=2))
    print(json.dumps(meta, indent=2))
    print(f"wrote probe_x / probe_torch_spec / probe_torch_stems to {OUT}")


if __name__ == "__main__":
    main()
