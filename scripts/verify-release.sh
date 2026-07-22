#!/usr/bin/env bash
#
# Pre-release gate — mirrors CI so a tag can't publish something CI would reject:
# regenerate the project, lint, enforce the SwiftUI boundary, then build + run the
# unit/integration suite on the shipping toolchain.
#
# Env:
#   SIGN_MODE   adhoc | developer-id   (default: adhoc) — gates optional checks
#
# Exit non-zero on the first failure.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SCHEME="SoundView"
SIGN_MODE="${SIGN_MODE:-adhoc}"

echo "==> xcodegen generate"
xcodegen generate

echo "==> SwiftLint"
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --quiet
else
  echo "   (swiftlint not installed — skipping)"
fi

echo "==> SwiftUI boundary check"
# Feature Views are presentation-only: they must route heavy work (Core ML,
# AVFoundation) through a view model / service, never import it directly.
if command -v rg >/dev/null 2>&1; then
  if rg -n --glob 'SoundView/Features/**/*View.swift' '^\s*import\s+(CoreML|AVFoundation)\b'; then
    echo "error: a Feature View imports a service framework directly — route via a view model." >&2
    exit 1
  fi
  echo "   ok — no View imports Core ML / AVFoundation directly"
else
  echo "   (ripgrep not installed — skipping boundary check)"
fi

echo "==> build + unit/integration tests"
UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
d = json.load(sys.stdin)['devices']
cands = [x['udid'] for k, v in d.items() if 'iOS' in k
         for x in v if x.get('isAvailable') and 'iPhone' in x['name']]
print(cands[0])
")
set -o pipefail
if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild test -project SoundView.xcodeproj -scheme "$SCHEME" \
    -destination "id=$UDID" -only-testing:SoundViewTests \
    CODE_SIGNING_ALLOWED=NO | xcbeautify
else
  xcodebuild test -project SoundView.xcodeproj -scheme "$SCHEME" \
    -destination "id=$UDID" -only-testing:SoundViewTests \
    CODE_SIGNING_ALLOWED=NO
fi

# A signed helper smoke test only makes sense with a real identity; ad-hoc builds
# can't exercise it, so skip rather than fail.
if [ "$SIGN_MODE" = "developer-id" ]; then
  echo "==> helper smoke test (developer-id)"
  # placeholder: exercise the signed helper here when one exists.
else
  echo "==> skipping helper smoke test under ad-hoc signing"
fi

echo "verify-release: OK"
