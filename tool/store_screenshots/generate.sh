#!/bin/bash
# Mağaza görsellerini yeniden üretir: store/play/<dil>,
# store/appstore/<iphone|iphone63|ipad>/<dil> ve store/appstore/creative.
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
# Uygulamanın arayüzü yalnızca Türkçe ve İngilizce; öteki dillerin görselleri
# İngilizce ekranlarla, o dilin başlıklarıyla üretilir.
for lang in de fr es pt ru id ar; do
  python3 tool/store_screenshots/compose.py "$RAW/en" "store/play/$lang" "$lang" "$FONTS"
done

# App Store: aynı görseller iPhone 6.9 inç ve iPad 13 inç ölçüsünde, uygulamanın
# iOS görünümüyle.
for device in iphone ipad; do
  for lang in tr en; do
    mkdir -p "$RAW/$device/$lang"
    "$FLUTTER" test tool/store_screenshots/shots_test.dart \
      --dart-define=SHOT_DIR="$RAW/$device/$lang" \
      --dart-define=SHOT_LANG="$lang" \
      --dart-define=SHOT_DEVICE="$device" \
      --dart-define=SHOT_FONTS="$FONTS"
  done
  for lang in tr en de fr es pt ru id ar; do
    raw="$RAW/$device/en"
    [ "$lang" = tr ] && raw="$RAW/$device/tr"
    python3 tool/store_screenshots/compose.py "$raw" "store/appstore/$device/$lang" "$lang" "$FONTS" "$device"
  done
done
# App Store'un zorunlu iPhone ölçüsü 6,3 inç (1206x2622); oranı 6,9 inçle
# neredeyse aynı olduğu için o görseller küçültülür.
python3 - <<'EOF'
import glob, os
from PIL import Image
for src in glob.glob('store/appstore/iphone/*/*.png'):
    out = src.replace('/iphone/', '/iphone63/')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.open(src).convert('RGB').resize((1206, 2622), Image.LANCZOS).save(out, optimize=True)
EOF
# iOS 27'nin ürün sayfası başlığı ve arama sonucu görselleri.
python3 tool/store_screenshots/creative.py "$RAW/iphone/tr" "$RAW/iphone/en" store/appstore/creative "$FONTS"
echo "Hazır: store/play/<dil>"
