# Security Policy

SoundView is a client-side app: all audio import, separation, mixing, and export
run **on-device**. No audio, telemetry, or account data is uploaded, so the network
attack surface is minimal by design.

## Reporting a vulnerability

Please report suspected vulnerabilities privately via GitHub's
[**Report a vulnerability**](https://github.com/JCTec/SoundView/security/advisories/new)
(Security → Advisories). Do **not** open a public issue for security reports.

Include repro steps, affected version/commit, and impact. I aim to acknowledge
within a few days. As a personal open-source project there is no formal SLA, but
valid reports will be addressed and credited if you wish.

## Scope

- ✅ In scope: the SoundView app code in this repository.
- ➖ Out of scope: third-party dependencies (report upstream), and the Demucs model
  weights themselves (Meta).
