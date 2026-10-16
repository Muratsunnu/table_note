"""Ham ekranları mağaza görsellerine çevirir.

Telefon görselleri 1080x1920: üstte başlık, altında uygulama ekranı. Google
Play'in önerisine uyar: telefon çerçevesi yok, başlık görselin beşte birini
geçmez. Öne çıkan görsel 1024x500.

    python3 compose.py <ham_klasör> <çıktı_klasör> <dil> <yazı_tipi_klasörü>

Diller CAPTIONS'ta; Türkçe dışındakiler İngilizce ham ekranları kullanır.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
TOP, BOTTOM = (0x3B, 0x82, 0xF6), (0x1D, 0x4E, 0xD8)  # logonun geçişi
CARD_Y, RADIUS = 368, 44
CAPTION_TOP, CAPTION_MAX = 96, 92

# Sıra mağazadaki sıradır; ilk üçü arama sonucunda görünür.
SHOTS = ['tablo', 'ses', 'cetele', 'paylasim', 'dosya', 'sablon', 'yedek']

# Uygulamanın arayüzü yalnızca Türkçe ve İngilizce. Öteki dillerde ekran
# görüntüleri İngilizce arayüzü gösterir; yalnızca başlıklar o dildedir.
CAPTIONS = {
    'tr': ['Tablonu kur,|hesabı o yapsın', 'Konuş,|satır dolsun',
           'Çetele tut,|gün gün işaretle', 'Kodu ver,|birlikte doldurun',
           'PDF ya da CSV|olarak paylaş', 'Şablonunu kaydet,|yeni tablo hazır',
           'Buluta yedekle,|verin kaybolmasın'],
    'en': ['Build your table,|it does the math', 'Just speak,|the row fills in',
           'Keep a tally,|mark each day', 'Share a code,|work together',
           'PDF or CSV,|shared in one tap', 'Save a template,|new table ready',
           'Back it up,|keep tables safe'],
    'de': ['Erstelle deine Tabelle,|sie rechnet für dich', 'Einfach sprechen,|die Zeile füllt sich',
           'Strichliste führen,|jeden Tag abhaken', 'Code teilen,|gemeinsam arbeiten',
           'PDF oder CSV,|mit einem Tipp geteilt', 'Vorlage speichern,|neue Tabelle fertig',
           'Sichern,|Tabellen bleiben sicher'],
    'fr': ['Créez votre tableau,|il fait les calculs', 'Parlez,|la ligne se remplit',
           'Tenez un pointage,|cochez chaque jour', 'Partagez un code,|travaillez ensemble',
           'PDF ou CSV,|partagé en un geste', 'Enregistrez un modèle,|nouveau tableau prêt',
           'Sauvegardez,|vos tableaux en sécurité'],
    'es': ['Crea tu tabla,|ella hace las cuentas', 'Solo habla,|la fila se llena',
           'Lleva un control,|marca cada día', 'Comparte un código,|trabajen juntos',
           'PDF o CSV,|compartido al instante', 'Guarda una plantilla,|nueva tabla lista',
           'Haz una copia,|tus tablas a salvo'],
    'pt': ['Monte sua tabela,|ela faz as contas', 'É só falar,|a linha se preenche',
           'Controle de presença,|marque cada dia', 'Compartilhe um código,|trabalhem juntos',
           'PDF ou CSV,|compartilhado num toque', 'Salve um modelo,|nova tabela pronta',
           'Faça backup,|suas tabelas seguras'],
    'ru': ['Создайте таблицу,|она всё посчитает', 'Просто скажите,|строка заполнится',
           'Ведите табель,|отмечайте каждый день', 'Поделитесь кодом,|работайте вместе',
           'PDF или CSV|одним касанием', 'Сохраните шаблон,|новая таблица готова',
           'Резервная копия,|таблицы в сохранности'],
    'id': ['Buat tabelmu,|hitungannya otomatis', 'Cukup bicara,|baris terisi sendiri',
           'Catat absensi,|tandai setiap hari', 'Bagikan kode,|kerja bareng',
           'PDF atau CSV,|bagikan sekali ketuk', 'Simpan template,|tabel baru siap',
           'Cadangkan,|tabel tetap aman'],
    'ar': ['أنشئ جدولك،|والحساب عليه', 'تحدّث فقط،|ويمتلئ الصف',
           'سجّل الحضور،|علّم كل يوم', 'شارك رمزًا،|واعملوا معًا',
           'PDF أو CSV|بلمسة واحدة', 'احفظ قالبًا،|وجدول جديد جاهز',
           'انسخ احتياطيًا،|وجداولك بأمان'],
}
TAGLINE = {
    'tr': 'Tablo, çetele ve hesap|tek uygulamada',
    'en': 'Tables, tallies and totals|in one app',
    'de': 'Tabellen, Strichlisten und|Summen in einer App',
    'fr': 'Tableaux, pointages et totaux|dans une seule app',
    'es': 'Tablas, conteos y totales|en una sola app',
    'pt': 'Tabelas, presenças e totais|em um só app',
    'ru': 'Таблицы, табели и итоги|в одном приложении',
    'id': 'Tabel, absensi, dan total|dalam satu aplikasi',
    'ar': 'جداول وحضور ومجاميع|في تطبيق واحد',
}
# Sağdan sola yazılan diller: başlık macOS'un metin motoruyla çizilir.
RTL = {'ar'}


def render_rtl(lines, width, size, out_path):
    """Satırları saydam bir PNG'ye çizer; (genişlik, yükseklik) döner."""
    here = os.path.dirname(os.path.abspath(__file__))
    result = subprocess.run(
        ['swift', os.path.join(here, 'render_text.swift'), out_path,
         str(width), str(size), '1', *lines],
        check=True, capture_output=True, text=True)
    w, h = result.stdout.split()
    return int(w), int(h)


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


def phone_shot(shot_path, caption, out_path, font, rtl=False):
    shot = Image.open(shot_path).convert('RGB')
    x = (W - shot.width) // 2
    image = place_card(background(W, H), shot, x, CARD_Y, RADIUS)
    lines = caption.split('|')
    if rtl:
        # Sağa yaslı: metnin sağ kenarı kartın sağ kenarıyla hizalanır.
        with tempfile.NamedTemporaryFile(suffix='.png') as tmp:
            render_rtl(lines, shot.width, font.size, tmp.name)
            text = Image.open(tmp.name).convert('RGBA')
            image.alpha_composite(text, (x, CAPTION_TOP - 6))
        image.convert('RGB').save(out_path)
        return
    draw = ImageDraw.Draw(image)
    step = round(font.size * 1.12)
    y = CAPTION_TOP + (CAPTION_MAX - font.size)
    for line in lines:
        draw.text((x, y), line, font=font, fill='white')
        y += step
    image.convert('RGB').save(out_path)


def feature_graphic(raw_dir, tagline, out_path, font_dir, mark_path, rtl=False):
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
    if rtl:
        with tempfile.NamedTemporaryFile(suffix='.png') as tmp:
            render_rtl(tagline.split('|'), 420, 31, tmp.name)
            text = Image.open(tmp.name).convert('RGBA')
            image.alpha_composite(text, (64, 296))
        image.convert('RGB').save(out_path)
        return
    small = ImageFont.truetype(os.path.join(font_dir, 'Roboto-Medium.ttf'), 31)
    y = 300
    for line in tagline.split('|'):
        draw.text((64, y), line, font=small, fill=(235, 242, 255))
        y += 42
    image.convert('RGB').save(out_path)


def main():
    raw_dir, out_dir, lang, font_dir = sys.argv[1:5]
    os.makedirs(out_dir, exist_ok=True)
    captions = CAPTIONS[lang]
    rtl = lang in RTL
    # Başlıklar takım içinde aynı boyda: en uzun satıra göre bir kez ölçülür.
    card_width = Image.open(os.path.join(raw_dir, SHOTS[0] + '.png')).width
    lines = [line for caption in captions for line in caption.split('|')]
    if rtl:
        size = CAPTION_MAX
        with tempfile.NamedTemporaryFile(suffix='.png') as tmp:
            while render_rtl(lines, 4000, size, tmp.name)[0] > card_width:
                size -= 2
        font = ImageFont.truetype(os.path.join(font_dir, 'Roboto-Black.ttf'), size)
    else:
        font = fit_font(os.path.join(font_dir, 'Roboto-Black.ttf'), lines,
                        card_width, CAPTION_MAX)
    for index, (name, caption) in enumerate(zip(SHOTS, captions), start=1):
        phone_shot(
            os.path.join(raw_dir, name + '.png'), caption,
            os.path.join(out_dir, f'{index:02d}_{name}.png'), font, rtl)
    here = os.path.dirname(os.path.abspath(__file__))
    mark = os.path.join(here, '..', '..', 'assets', 'logo', 'table_note_mark_white_1024.png')
    feature_graphic(raw_dir, TAGLINE[lang], os.path.join(out_dir, 'one_cikan_1024x500.png'),
                    font_dir, mark, rtl)


if __name__ == '__main__':
    main()
