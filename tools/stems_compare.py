#!/usr/bin/env python3
"""Compare full Swift pipeline stems vs torch full-model stems.
Both flat float32 [S, C, segment], source order = manifest.sources."""
import json
import sys
from pathlib import Path

import numpy as np

D = Path(sys.argv[1])
meta = json.loads((D / "probe_meta.json").read_text())
S = len(meta["sources"])
C, seg = meta["channels"], meta["segment"]
nfft = 4096

t = np.fromfile(D / "probe_torch_stems.f32", "<f4").reshape(S, C, seg)
s = np.fromfile(D / "probe_swift_stems.f32", "<f4").reshape(S, C, seg)


def snr(ref, cand):
    ref, cand = ref.reshape(-1).astype(np.float64), cand.reshape(-1).astype(np.float64)
    n = np.sum((cand - ref) ** 2) + 1e-20
    return 10 * np.log10((np.sum(ref ** 2) + 1e-20) / n)


# Trim edges (OLA zeroes ~window at the boundaries) to judge the interior.
sl = slice(nfft, seg - nfft)
print(f"stems torch={t.shape} swift={s.shape}  (interior trim {nfft})")
for i, src in enumerate(meta["sources"]):
    ti, si = t[i, :, sl], s[i, :, sl]
    line = (f"[{src:6s}] SNR {snr(ti, si):6.1f} dB  "
            f"torch_rms {np.sqrt(np.mean(ti**2)):.5f}  swift_rms {np.sqrt(np.mean(si**2)):.5f}")
    # per-channel + channel-swap probe
    swap = snr(ti, si[::-1])
    k = float(np.sum(ti * si) / (np.sum(si * si) + 1e-20))
    line += f"  | chan-swap {swap:5.1f}  best-scale k={k:.3f}→{snr(ti, k*si):5.1f}"
    print(line)

print(f"\nALL interior SNR = {snr(t[:, :, sl], s[:, :, sl]):6.1f} dB")
# Does Swift reconstruct the mix? sum of stems vs torch sum
print(f"sum-stems SNR    = {snr(t[:, :, sl].sum(0), s[:, :, sl].sum(0)):6.1f} dB")
