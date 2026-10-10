#!/bin/bash
# Mağaza görsellerini yeniden üretir: store/play/tr ve store/play/en.
#
#   tool/store_screenshots/generate.sh
#
# Gerekenler: flutter (PATH'te ya da FLUTTER değişkeninde) ve python3 + Pillow.
set -euo pipefail

cd "$(dirname "$0")/../.."
FLUTTER="${FLUTTER:-flutter}"
FONTS="$(dirname "$(command -v "$FLUTTER")")/cache/artifacts/material_fonts"
RAW="$(mktemp -d)"
trap 'rm -rf "$RAW"' EXIT

for lang in tr en; do
  mkdir -p "$RAW/$lang"
  "$FLUTTER" test tool/store_screenshots/shots_test.dart \
    --dart-define=SHOT_DIR="$RAW/$lang" \
    --dart-define=SHOT_LANG="$lang" \
    --dart-define=SHOT_FONTS="$FONTS"
  python3 tool/store_screenshots/compose.py "$RAW/$lang" "store/play/$lang" "$lang" "$FONTS"
done
echo "Hazır: store/play/tr ve store/play/en"
