#!/usr/bin/env bash
#
# Fetch the bundled Demucs Core ML models from GitHub Releases into
# SoundView/Resources/. The ~412 MB of weights are NOT stored in git (they're
# Meta's CC-BY-NC checkpoint); this pulls the release asset built by the
# "Release models" workflow (or `tools/convert_htdemucs.py` locally).
#
#   ./tools/fetch_models.sh [TAG]     # default tag: models-v1
#
# Uses the GitHub CLI if available, otherwise curl on the public asset URL.
set -euo pipefail

REPO="JCTec/SoundView"
TAG="${1:-models-v1}"
ASSET="htdemucs_ft_coreml.zip"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/SoundView/Resources"

mkdir -p "$DEST"
cd "$DEST"

if [ -d "htdemucs_ft_vocals.mlpackage" ]; then
  echo "✓ Models already present in $DEST (delete them to re-fetch)."
  exit 0
fi

echo "Fetching $ASSET ($TAG) from $REPO …"
if command -v gh >/dev/null 2>&1; then
  gh release download "$TAG" --repo "$REPO" --pattern "$ASSET" --dir . --clobber
else
  curl -fL --retry 3 -o "$ASSET" \
    "https://github.com/$REPO/releases/download/$TAG/$ASSET"
fi

echo "Unpacking …"
unzip -oq "$ASSET"
rm -f "$ASSET"

echo "✓ Installed:"
ls -1d "$DEST"/*.mlpackage
echo "Manifest: $DEST/htdemucs_manifest.json"
