#!/usr/bin/env python3
"""Compare Swift DemucsSpec.forward output vs torch reference_spec.
Both are flat float32 [2C, bins, frames] in channel order [c0r, c0i, c1r, c1i],
plane layout bin*frames+frame. Reports overall + per-plane SNR and probes common
layout bugs (sign/conjugate, real<->imag swap, bin<->frame transpose)."""
import json
import sys
from pathlib import Path

import numpy as np

D = Path(sys.argv[1])
meta = json.loads((D / "probe_meta.json").read_text())
C, bins, frames = meta["channels"], meta["bins"], meta["frames"]
planes = 2 * C

t = np.fromfile(D / "probe_torch_spec.f32", "<f4").reshape(planes, bins, frames)
s = np.fromfile(D / "probe_swift_spec.f32", "<f4").reshape(planes, bins, frames)


def snr(ref, cand):
    ref, cand = ref.reshape(-1).astype(np.float64), cand.reshape(-1).astype(np.float64)
    noise = np.sum((cand - ref) ** 2) + 1e-20
    return 10 * np.log10((np.sum(ref ** 2) + 1e-20) / noise)


print(f"shapes torch={t.shape} swift={s.shape}")
print(f"torch rms={np.sqrt(np.mean(t**2)):.5f}  swift rms={np.sqrt(np.mean(s**2)):.5f}")
print(f"OVERALL SNR = {snr(t, s):6.1f} dB")
labels = [f"c{c}{'ri'[r]}" for c in range(C) for r in range(2)]
for i, lab in enumerate(labels):
    print(f"  plane {lab}: SNR {snr(t[i], s[i]):6.1f} dB  "
          f"torch_rms {np.sqrt(np.mean(t[i]**2)):.5f} swift_rms {np.sqrt(np.mean(s[i]**2)):.5f}")

print("\n-- layout-bug probes (higher SNR after a transform ⇒ that's the bug) --")
# imag sign flip (conjugate): flip every imag plane
sconj = s.copy()
sconj[1::2] *= -1
print(f"  conjugate (flip imag sign): {snr(t, sconj):6.1f} dB")
# real<->imag swap within each channel
sswap = s.copy()
sswap[0::2], sswap[1::2] = s[1::2], s[0::2]
print(f"  real<->imag swap:           {snr(t, sswap):6.1f} dB")
# bin<->frame transpose (only valid if square-ish; compare on min dim)
try:
    st = np.transpose(s, (0, 2, 1))
    if st.shape == t.shape:
        print(f"  bin<->frame transpose:      {snr(t, st):6.1f} dB")
except Exception as e:  # noqa: BLE001
    print("  transpose n/a:", e)
# global scale (least-squares best scalar)
k = float(np.sum(t * s) / (np.sum(s * s) + 1e-20))
print(f"  best global scale k={k:.4f}: {snr(t, k * s):6.1f} dB")
