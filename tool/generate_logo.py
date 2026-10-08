#!/usr/bin/env python3
"""Table Note logosunu ve ondan türeyen ikon/açılış görsellerini üretir.

Gerekenler: rsvg-convert (librsvg) ve Pillow.
Çalıştırma: python3 tool/generate_logo.py
"""

import io
import json
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / 'assets/logo'
RES = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets'

TOP, BOTTOM = '#3B82F6', '#1D4ED8'
CANVAS = 1024
CELL, GAP, RADIUS = 176, 40, 46
GRID = 3 * CELL + 2 * GAP
# T'yi oluşturmayan dört hücrenin görünürlüğü.
GHOST = 0.28

# Açılış ekranında işaretin kenar uzunluğu (dp / pt); iki platformda aynı.
SPLASH_MARK = 120
# Android uyarlanabilir ikon tuvali ve işaretin güvenli alana sığan boyutu.
ADAPTIVE_CANVAS, ADAPTIVE_GRID = 108, 45


def cells(origin, scale=1.0):
    """Her hücre için (x, y, T'nin parçası mı)."""
    step = (CELL + GAP) * scale
    for row in range(3):
        for col in range(3):
            yield origin + col * step, origin + row * step, row == 0 or col == 1


def mark_rects(origin):
    rects = []
    for x, y, solid in cells(origin):
        opacity = '' if solid else f' fill-opacity="{GHOST}"'
        rects.append(
            f'<rect x="{x:g}" y="{y:g}" width="{CELL}" height="{CELL}" '
            f'rx="{RADIUS}" fill="#fff"{opacity}/>'
        )
    return '\n  '.join(rects)


def logo_svg(corner=0):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{TOP}"/>
      <stop offset="1" stop-color="{BOTTOM}"/>
    </linearGradient>
  </defs>
  <rect width="{CANVAS}" height="{CANVAS}" rx="{corner}" fill="url(#bg)"/>
  {mark_rects((CANVAS - GRID) / 2)}
</svg>
'''


def mark_svg():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {GRID} {GRID}">
  {mark_rects(0)}
</svg>
'''


def render(svg, size, path, opaque=False):
    png = subprocess.run(
        ['rsvg-convert', '-w', str(size), '-h', str(size)],
        input=svg.encode(),
        capture_output=True,
        check=True,
    ).stdout
    image = Image.open(io.BytesIO(png))
    # App Store ikonunda saydamlık kanalı kabul edilmiyor.
    if opaque:
        image = image.convert('RGB')
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def rounded_rect_path(x, y, size, radius):
    side = size - 2 * radius
    r = f'{radius:.3f}'
    return (
        f'M{x + radius:.3f},{y:.3f} h{side:.3f} a{r},{r} 0 0 1 {r},{r} '
        f'v{side:.3f} a{r},{r} 0 0 1 -{r},{r} h-{side:.3f} '
        f'a{r},{r} 0 0 1 -{r},-{r} v-{side:.3f} a{r},{r} 0 0 1 {r},-{r} z'
    )


def adaptive_foreground_xml():
    scale = ADAPTIVE_GRID / GRID
    origin = (ADAPTIVE_CANVAS - ADAPTIVE_GRID) / 2
    solid, ghost = [], []
    for x, y, on in cells(origin, scale):
        (solid if on else ghost).append(
            rounded_rect_path(x, y, CELL * scale, RADIUS * scale)
        )
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- tool/generate_logo.py üretir; elle düzenleme. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{ADAPTIVE_CANVAS}dp"
    android:height="{ADAPTIVE_CANVAS}dp"
    android:viewportWidth="{ADAPTIVE_CANVAS}"
    android:viewportHeight="{ADAPTIVE_CANVAS}">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="{' '.join(solid)}" />
    <path
        android:fillAlpha="{GHOST}"
        android:fillColor="#FFFFFF"
        android:pathData="{' '.join(ghost)}" />
</vector>
'''


def main():
    square, rounded, mark = logo_svg(), logo_svg(corner=230), mark_svg()

    # Ana dosyalar
    LOGO.mkdir(parents=True, exist_ok=True)
    (LOGO / 'table_note_logo.svg').write_text(square)
    (LOGO / 'table_note_mark_white.svg').write_text(mark)
    render(square, 1024, LOGO / 'table_note_logo_1024.png', opaque=True)
    render(square, 512, LOGO / 'table_note_play_store_512.png', opaque=True)
    render(rounded, 1024, LOGO / 'table_note_logo_rounded_1024.png')
    render(mark, 1024, LOGO / 'table_note_mark_white_1024.png')

    # Android
    (RES / 'drawable/ic_launcher_foreground.xml').write_text(
        adaptive_foreground_xml()
    )
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for density, size in densities.items():
        render(rounded, size, RES / f'mipmap-{density}/ic_launcher.png')

    # iOS
    icons = IOS / 'AppIcon.appiconset'
    for entry in json.loads((icons / 'Contents.json').read_text())['images']:
        points = float(entry['size'].split('x')[0])
        pixels = round(points * int(entry['scale'][0]))
        render(square, pixels, icons / entry['filename'], opaque=True)
    for scale in (1, 2, 3):
        suffix = '' if scale == 1 else f'@{scale}x'
        render(
            mark,
            SPLASH_MARK * scale,
            IOS / f'LaunchImage.imageset/LaunchImage{suffix}.png',
        )


if __name__ == '__main__':
    main()
