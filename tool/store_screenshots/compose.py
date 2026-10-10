"""Ham ekranları mağaza görsellerine çevirir.

Telefon görselleri 1080x1920: üstte başlık, altında uygulama ekranı. Google
Play'in önerisine uyar: telefon çerçevesi yok, başlık görselin beşte birini
geçmez. Öne çıkan görsel 1024x500.

    python3 compose.py <ham_klasör> <çıktı_klasör> <tr|en> <yazı_tipi_klasörü>
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
TOP, BOTTOM = (0x3B, 0x82, 0xF6), (0x1D, 0x4E, 0xD8)  # logonun geçişi
CARD_Y, RADIUS = 368, 44
CAPTION_TOP, CAPTION_MAX = 96, 92

# Sıra mağazadaki sıradır; ilk üçü arama sonucunda görünür.
SHOTS = [
    ('tablo', 'Tablonu kur,|hesabı o yapsın', 'Build your table,|it does the math'),
    ('ses', 'Konuş,|satır dolsun', 'Just speak,|the row fills in'),
    ('cetele', 'Çetele tut,|gün gün işaretle', 'Keep a tally,|mark each day'),
    ('paylasim', 'Kodu ver,|birlikte doldurun', 'Share a code,|work together'),
    ('dosya', 'PDF ya da CSV|olarak paylaş', 'PDF or CSV,|shared in one tap'),
    ('sablon', 'Şablonunu kaydet,|yeni tablo hazır', 'Save a template,|new table ready'),
    ('yedek', 'Buluta yedekle,|verin kaybolmasın', 'Back it up,|keep tables safe'),
]
TAGLINE = {
    'tr': 'Tablo, çetele ve hesap|tek uygulamada',
    'en': 'Tables, tallies and totals|in one app',
}


def background(width, height, rows=6, fade=4.6):
    column = Image.new('RGB', (1, height))
    for y in range(height):
        t = y / (height - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    image = column.resize((width, height)).convert('RGBA')
    # Logodaki soluk hücreler: üstte belirgin, aşağı doğru kaybolur.
    cells = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(cells)
    size, gap = 138, 32
    count = (width - 44) // (size + gap)
    left = (width - (count * size + (count - 1) * gap)) // 2
    for row in range(rows):
        y = 44 + row * (size + gap)
        alpha = max(0, round(17 * (1 - row / fade)))
        for col in range(count):
            x = left + col * (size + gap)
            draw.rounded_rectangle((x, y, x + size, y + size), 32, fill=(255, 255, 255, alpha))
    return Image.alpha_composite(image, cells)


def place_card(image, shot, x, y, radius, shadow_offset=34, blur=40):
    shadow = Image.new('RGBA', image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x, y + shadow_offset, x + shot.width, y + shot.height + shadow_offset),
        radius, fill=(8, 20, 70, 120))
    image = Image.alpha_composite(image, shadow.filter(ImageFilter.GaussianBlur(blur)))
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, shot.width - 1, shot.height - 1), radius, fill=255)
    image.paste(shot, (x, y), mask)
    return image


def fit_font(path, lines, width, largest):
    size = largest
    while True:
        font = ImageFont.truetype(path, size)
        if max(font.getlength(line) for line in lines) <= width:
            return font
        size -= 2


def phone_shot(shot_path, caption, out_path, font):
    shot = Image.open(shot_path).convert('RGB')
    x = (W - shot.width) // 2
    image = place_card(background(W, H), shot, x, CARD_Y, RADIUS)
    lines = caption.split('|')
    draw = ImageDraw.Draw(image)
    step = round(font.size * 1.12)
    y = CAPTION_TOP + (CAPTION_MAX - font.size)
    for line in lines:
        draw.text((x, y), line, font=font, fill='white')
        y += step
    image.convert('RGB').save(out_path)


def feature_graphic(raw_dir, tagline, out_path, font_dir, mark_path):
    width, height = 1024, 500
    image = background(width, height, rows=3, fade=3.4)

    # Sağda uygulamadan iki parça: önde tablo ve toplamları, arkada çetele.
    tally = Image.open(os.path.join(raw_dir, 'cetele.png')).convert('RGB')
    tally = tally.crop((0, 492, tally.width, 1032))
    tally = tally.resize((round(tally.width * 0.47), round(tally.height * 0.47)), Image.LANCZOS)
    image = place_card(image, tally, 690, 196, 20, shadow_offset=14, blur=18)

    table = Image.open(os.path.join(raw_dir, 'tablo.png')).convert('RGB')
    table = table.crop((0, 250, table.width, 1150))
    table = table.resize((round(table.width * 0.47), round(table.height * 0.47)), Image.LANCZOS)
    image = place_card(image, table, 520, 40, 22, shadow_offset=16, blur=20)

    draw = ImageDraw.Draw(image)
    mark = Image.open(mark_path).convert('RGBA').resize((84, 84), Image.LANCZOS)
    image.alpha_composite(mark, (60, 96))
    draw = ImageDraw.Draw(image)
    name = ImageFont.truetype(os.path.join(font_dir, 'Roboto-Black.ttf'), 78)
    draw.text((62, 196), 'Table Note', font=name, fill='white')
    small = ImageFont.truetype(os.path.join(font_dir, 'Roboto-Medium.ttf'), 31)
    y = 300
    for line in tagline.split('|'):
        draw.text((64, y), line, font=small, fill=(235, 242, 255))
        y += 42
    image.convert('RGB').save(out_path)


def main():
    raw_dir, out_dir, lang, font_dir = sys.argv[1:5]
    os.makedirs(out_dir, exist_ok=True)
    captions = [tr if lang == 'tr' else en for _, tr, en in SHOTS]
    # Başlıklar takım içinde aynı boyda: en uzun satıra göre bir kez ölçülür.
    card_width = Image.open(os.path.join(raw_dir, SHOTS[0][0] + '.png')).width
    font = fit_font(
        os.path.join(font_dir, 'Roboto-Black.ttf'),
        [line for caption in captions for line in caption.split('|')],
        card_width, CAPTION_MAX)
    for index, ((name, _, _), caption) in enumerate(zip(SHOTS, captions), start=1):
        phone_shot(
            os.path.join(raw_dir, name + '.png'), caption,
            os.path.join(out_dir, f'{index:02d}_{name}.png'), font)
    here = os.path.dirname(os.path.abspath(__file__))
    mark = os.path.join(here, '..', '..', 'assets', 'logo', 'table_note_mark_white_1024.png')
    feature_graphic(raw_dir, TAGLINE[lang], os.path.join(out_dir, 'one_cikan_1024x500.png'), font_dir, mark)


if __name__ == '__main__':
    main()
