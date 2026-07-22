#!/usr/bin/env bash
#
# Build → sign → (optionally) notarize → package the macOS app into a DMG.
#
# Best-effort signing:
#   • With a Developer ID cert + App Store Connect notary key (via env/secrets),
#     produces a signed, notarized, stapled, distributable DMG.
#   • Without them, ad-hoc signs so the pipeline still yields a DMG for testing
#     (NOT distributable — Gatekeeper will block it on other machines).
#
# Env (all optional unless noted):
#   VERSION                    release version (default: `git describe`)
#   OUTPUT_DIR                 artifact dir (default: dist)
#   MACOS_CERT_P12_BASE64      base64 of a Developer ID Application .p12
#   MACOS_CERT_PASSWORD        password for that .p12
#   NOTARY_KEY_ID              App Store Connect API key id
#   NOTARY_ISSUER_ID           App Store Connect issuer id
#   NOTARY_KEY_P8_BASE64       base64 of the .p8 API key
#
# Emits (stdout): SIGN_MODE=... and DMG=... for the caller to consume.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SCHEME="SoundView"
VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null || echo dev)}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
ARCHIVE="$OUTPUT_DIR/SoundView-macos.xcarchive"
TMP="${RUNNER_TEMP:-$(mktemp -d)}"
mkdir -p "$OUTPUT_DIR"

command -v xcodegen >/dev/null 2>&1 && xcodegen generate

echo "==> archiving macOS app ($VERSION)"
xcodebuild archive \
  -project SoundView.xcodeproj \
  -scheme "$SCHEME" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO

APP="$(/usr/bin/find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' | head -1)"
[ -d "$APP" ] || { echo "error: no .app found in archive" >&2; exit 1; }

# ---- signing ----
SIGN_MODE="adhoc"
if [ -n "${MACOS_CERT_P12_BASE64:-}" ] && [ -n "${MACOS_CERT_PASSWORD:-}" ]; then
  SIGN_MODE="developer-id"
  KEYCHAIN="$TMP/soundview-signing.keychain-db"
  KPASS="$(uuidgen)"
  security create-keychain -p "$KPASS" "$KEYCHAIN"
  security set-keychain-settings -lut 3600 "$KEYCHAIN"
  security unlock-keychain -p "$KPASS" "$KEYCHAIN"
  printf '%s' "$MACOS_CERT_P12_BASE64" | base64 --decode > "$TMP/cert.p12"
  security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$MACOS_CERT_PASSWORD" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KPASS" "$KEYCHAIN" >/dev/null
  # Keep the login keychain in the search list too.
  security list-keychains -d user -s "$KEYCHAIN" login.keychain-db
  IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" \
    | grep 'Developer ID Application' | head -1 | awk '{print $2}')"
  [ -n "$IDENTITY" ] || { echo "error: no Developer ID Application identity in the imported cert" >&2; exit 1; }
  echo "==> signing with Developer ID ($IDENTITY)"
  codesign --force --deep --options runtime --timestamp -s "$IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  echo "==> no Developer ID secrets — ad-hoc signing (NOT distributable)"
  codesign --force --deep -s - "$APP"
fi

DMG="$OUTPUT_DIR/SoundView-$VERSION.dmg"
"$ROOT/scripts/package-dmg.sh" "$APP" "$DMG" "SoundView $VERSION"

# ---- notarization (Developer ID only) ----
if [ "$SIGN_MODE" = "developer-id" ] && [ -n "${NOTARY_KEY_P8_BASE64:-}" ] \
   && [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER_ID:-}" ]; then
  echo "==> notarizing (notarytool, waits for result)"
  printf '%s' "$NOTARY_KEY_P8_BASE64" | base64 --decode > "$TMP/notary.p8"
  xcrun notarytool submit "$DMG" \
    --key "$TMP/notary.p8" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER_ID" \
    --wait
  xcrun stapler staple "$DMG"
  echo "==> notarized + stapled"
else
  echo "==> skipping notarization (needs Developer ID cert + notary key secrets)"
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"

# Consumable by the workflow (e.g. `eval` or GITHUB_OUTPUT).
echo "SIGN_MODE=$SIGN_MODE"
echo "DMG=$DMG"
