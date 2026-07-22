#!/usr/bin/env bash
#
# Package a macOS .app into a compressed, drag-to-install DMG.
#
#   package-dmg.sh <path/to/App.app> <output.dmg> [volume-name]
set -euo pipefail

APP="${1:?usage: package-dmg.sh <App.app> <output.dmg> [volume-name]}"
DMG="${2:?output .dmg path required}"
VOL="${3:-SoundView}"

[ -d "$APP" ] || { echo "error: no app bundle at $APP" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications" # drag-to-install target

rm -f "$DMG"
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG"

echo "wrote $DMG"
