"""App Store'un iOS 27 ile gelen yaratıcı görsellerini üretir.

Ürün sayfası başlığı 3840x1646 (21:9), arama sonucu görseli 3840x2560 (3:2).
Önemli her şey Apple şablonlarındaki güvenli alanda durur; dışarısı cihaza ve
yöne göre kırpılabilir. Başlıkta yazı yok, yalnızca uygulamanın ekranları;
arama görselinde o dilde kısa bir başlık var.

    python3 creative.py <ham_tr> <ham_en> <çıktı_klasör> <yazı_tipi_klasörü>

Ham ekranlar shots_test.dart'ın iPhone çıktısıdır (SHOT_DEVICE=iphone).
"""
import os
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from compose import RTL, render_rtl

HEADER = (3840, 1646)
HEADER_SAFE = (1097, 493, 2743, 1154)
SEARCH = (3840, 2560)
SEARCH_SAFE = (836, 765, 3004, 1795)

# Logonun mavileri: sol üst açık, sağ alt koyu.
CORNERS = [(0x4A, 0x8F, 0xF8), (0x3B, 0x82, 0xF6), (0x25, 0x63, 0xEB), (0x1D, 0x4E, 0xD8)]

# Arama sonucunda uygulamanın ne olduğu bir bakışta anlaşılsın: kısa, büyük.
HEADLINES = {
    'tr': 'Tablo, çetele|ve hesap|tek yerde',
    'en': 'Tables,|tallies|and totals',
    'de': 'Tabellen,|Strichlisten|und Summen',
    'fr': 'Tableaux,|pointages|et totaux',
    'es': 'Tablas,|conteos|y totales',
    'pt': 'Tabelas,|presenças|e totais',
    'ru': 'Таблицы,|табели|и итоги',
    'id': 'Tabel,|absensi,|dan total',
    'ar': 'جداول|وحضور|ومجاميع',
}


def gradient(size):
    """Dört köşe renginden yumuşak bir geçiş."""
    corners = Image.new('RGB', (2, 2))
    corners.putdata(CORNERS)
    return corners.resize(size, Image.BILINEAR).convert('RGBA')


def cells(size, cell, gap, alpha, fade_rows):
    """Logodaki soluk hücreler; üstte belirgin, aşağı doğru kaybolur."""
    width, height = size
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    step = cell + gap
    count = width // step + 1
    left = (width - (count * step - gap)) // 2
    for row in range(height // step + 1):
        a = max(0, round(alpha * (1 - row / fade_rows)))
        if not a:
            break
        y = gap + row * step
        for col in range(count):
            x = left + col * step
            draw.rounded_rectangle((x, y, x + cell, y + cell), round(cell * 0.23),
                                   fill=(255, 255, 255, a))
    return layer


def glow(size, center, radius, alpha):
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    x, y = center
    rx, ry = radius
    ImageDraw.Draw(layer).ellipse((x - rx, y - ry, x + rx, y + ry), fill=(255, 255, 255, alpha))
    return layer.filter(ImageFilter.GaussianBlur(min(rx, ry) * 0.6))


def card(shot_path, scale, radius):
    """Ekranı ölçekler, köşelerini yuvarlar; saydam kenarlı RGBA döner."""
    shot = Image.open(shot_path).convert('RGB')
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), radius,
                                           fill=255)
    shot = shot.convert('RGBA')
    shot.putalpha(mask)
    return shot


def drop(image, piece, top_center, angle=0, shadow=(40, 60, 120)):
    """Kartı üst kenarının ortası verilen noktaya gelecek şekilde, gölgesiyle koyar."""
    offset, blur, alpha = shadow
    pad = blur * 3
    framed = Image.new('RGBA', (piece.width + 2 * pad, piece.height + 2 * pad), (0, 0, 0, 0))
    framed.alpha_composite(piece, (pad, pad))
    if angle:
        framed = framed.rotate(angle, resample=Image.BICUBIC, expand=True)
    x = round(top_center[0] - framed.width / 2)
    y = round(top_center[1] - pad - (framed.height - piece.height - 2 * pad) / 2)
    dark = Image.new('RGBA', framed.size, (8, 20, 70, 0))
    dark.putalpha(framed.getchannel('A').point(lambda v: v * alpha // 255))
    dark = dark.filter(ImageFilter.GaussianBlur(blur))
    # Kart görselin kenarından taşabilir; geniş bir tuvalde birleştirip kırpılır.
    margin = max(framed.size)
    width, height = image.size
    layer = Image.new('RGBA', (width + 2 * margin, height + 2 * margin), (0, 0, 0, 0))
    layer.alpha_composite(dark, (x + margin, y + offset + margin))
    image = Image.alpha_composite(image, layer.crop((margin, margin, margin + width, margin + height)))
    layer = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    layer.alpha_composite(framed, (x + margin, y + margin))
    return Image.alpha_composite(image, layer.crop((margin, margin, margin + width, margin + height)))


def header(raw_dir, out_path):
    """Yazısız başlık: ortada tablo, iki yanında çetele ve sesle kayıt.

    Kartlar güvenli alanın üstünden başlar; iPhone'da üst kenarı kamera
    çentiği ve geri/paylaş düğmeleri örter.
    """
    image = gradient(HEADER)
    image = Image.alpha_composite(image, cells(HEADER, 230, 60, 13, 5))
    cx = (HEADER_SAFE[0] + HEADER_SAFE[2]) // 2
    image = Image.alpha_composite(image, glow(HEADER, (cx, 1000), (900, 520), 70))
    # Yanlardaki kartlar biraz geride ve eğik; kare kırpımda yarısı görünür.
    side = 0.78
    image = drop(image, card(os.path.join(raw_dir, 'cetele.png'), side, 48),
                 (cx - 700, 630), angle=7, shadow=(30, 50, 110))
    image = drop(image, card(os.path.join(raw_dir, 'ses.png'), side, 48),
                 (cx + 700, 630), angle=-7, shadow=(30, 50, 110))
    image = drop(image, card(os.path.join(raw_dir, 'tablo.png'), 0.9, 56),
                 (cx, 480), shadow=(40, 70, 140))
    image.convert('RGB').save(out_path, optimize=True)


def fit(font_path, lines, width, largest):
    size = largest
    while True:
        font = ImageFont.truetype(font_path, size)
        if max(font.getlength(line) for line in lines) <= width:
            return font
        size -= 4


def search(raw_dir, lang, out_path, font_dir):
    """Solda başlık, sağda iki ekran. Arapçada yerler yer değiştirir."""
    rtl = lang in RTL
    image = gradient(SEARCH)
    image = Image.alpha_composite(image, cells(SEARCH, 280, 72, 13, 6))
    left, top, right, bottom = SEARCH_SAFE
    middle = (top + bottom) // 2
    column = 1120  # başlığa ayrılan genişlik

    # Ekranlar: önde tablo, arkada çetele. Güvenli şerit satırlara denk gelir.
    def x_of(value):
        return SEARCH[0] - value if rtl else value

    back_x, front_x = right + 120, left + column + 560
    image = Image.alpha_composite(
        image, glow(SEARCH, (x_of((back_x + front_x) // 2), middle), (900, 800), 60))
    image = drop(image, card(os.path.join(raw_dir, 'cetele.png'), 0.8, 52),
                 (x_of(back_x), 470), angle=-5 if not rtl else 5, shadow=(34, 56, 120))
    image = drop(image, card(os.path.join(raw_dir, 'tablo.png'), 0.86, 56),
                 (x_of(front_x), 330), shadow=(40, 70, 140))

    lines = HEADLINES[lang].split('|')
    if rtl:
        size = 230
        with tempfile.NamedTemporaryFile(suffix='.png') as tmp:
            while True:
                width, height = render_rtl(lines, 3000, size, tmp.name)
                if width <= column:
                    break
                size -= 4
            render_rtl(lines, column, size, tmp.name)
            text = Image.open(tmp.name).convert('RGBA')
        image.alpha_composite(text, (SEARCH[0] - left - column, middle - text.height // 2))
    else:
        font = fit(os.path.join(font_dir, 'Roboto-Black.ttf'), lines, column, 230)
        step = round(font.size * 1.1)
        ascent, descent = font.getmetrics()
        block = step * (len(lines) - 1) + ascent + descent
        y = middle - block // 2
        draw = ImageDraw.Draw(image)
        for line in lines:
            draw.text((left, y), line, font=font, fill='white')
            y += step
    image.convert('RGB').save(out_path, optimize=True)


def main():
    raw_tr, raw_en, out_dir, font_dir = sys.argv[1:5]
    os.makedirs(out_dir, exist_ok=True)
    # Arayüz yalnızca Türkçe ve İngilizce; öteki diller İngilizce ekranı kullanır.
    header(raw_tr, os.path.join(out_dir, 'header_tr.png'))
    header(raw_en, os.path.join(out_dir, 'header_en.png'))
    for lang in HEADLINES:
        search(raw_tr if lang == 'tr' else raw_en, lang,
               os.path.join(out_dir, f'search_{lang}.png'), font_dir)


if __name__ == '__main__':
    main()
