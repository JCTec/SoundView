# GitHub setup — human checklist

Steps that need a human (secrets, repo settings, one-time toggles). Everything
else — CI, CodeQL, label sync, the release pipeline — is automated in
`.github/`.

## Automation already in the repo

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | push to `main`, PRs | Build · SwiftLint · unit/integration tests (Xcode `latest-stable`) |
| `codeql.yml` | push/PR to `main`, weekly | CodeQL security analysis (Swift) |
| `labels-sync.yml` | changes to `.github/labels.yml` | Applies label definitions to the repo |
| `release-models.yml` | manual | Publishes the Core ML model weights as a Release asset |
| `release.yml` | tag `v*` | Build → sign → notarize → package DMG → publish a GitHub Release |

## One-time repo settings

- [ ] **Actions enabled** (Settings → Actions → General → Allow all actions).
- [ ] **Workflow permissions**: "Read and write" (needed by `release.yml` and
      `labels-sync.yml`) — Settings → Actions → General → Workflow permissions.
- [ ] Confirm **`main` is the default branch**.
- [ ] (Optional) Branch protection on `main`: require the **CI** and **CodeQL**
      checks to pass before merge.
- [ ] **Enable code scanning** so CodeQL results appear in the Security tab —
      Settings → Code security → Code scanning. Free once the repo is **public**;
      on a **private** repo it needs **GitHub Advanced Security**. Until then the
      CodeQL workflow still runs the analysis each push but the upload soft-fails
      (the check stays green); it starts publishing automatically once enabled.

## Release signing (for a distributable macOS DMG)

`release.yml` runs on any `v*` tag. **Without** the secrets below it still
produces a DMG, but ad-hoc-signed and marked **pre-release** (Gatekeeper blocks
it on other Macs). To ship a signed, notarized release, add these repo secrets
(Settings → Secrets and variables → Actions):

- [ ] `MACOS_CERT_P12_BASE64` — `base64` of your **Developer ID Application**
      certificate exported as `.p12`
- [ ] `MACOS_CERT_PASSWORD` — password for that `.p12`
- [ ] `NOTARY_KEY_ID` — App Store Connect API key ID
- [ ] `NOTARY_ISSUER_ID` — App Store Connect issuer ID
- [ ] `NOTARY_KEY_P8_BASE64` — `base64` of the `.p8` API key

```sh
# examples for producing the base64 secrets
base64 -i DeveloperID_Application.p12 | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Then cut a release:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

## Model weights (fresh clones)

The four Core ML models (~412 MB, CC-BY-NC) are **not** in git.

- [ ] Publish them once so `make models` works for clones: run the
      **Release models** workflow, or locally `make release-models`.

## Notes

- The reference-stem dev pack (`Fixtures/Audio/Idilio-stems`, ~312 MB) is a
  DEBUG-only convenience and is git-ignored — not required to build.
- CI/release run on Xcode `latest-stable` to match the shipping toolchain.
