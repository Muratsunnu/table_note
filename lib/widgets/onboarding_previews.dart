import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Tanitim ekranindaki ornek tablo, cetele ve sesle kayit.
///
/// Ekran goruntusu degil, cizim. Sebepleri: karanlik mod kendiliginden
/// dogru calisir, sutun adlari uygulamanin diliyle gelir, her ekran
/// boyutunda keskin kalir ve arayuz degistiginde eskiyip yalan soylemez.
///
/// Renkler uygulamanin kendi paletinden (AppTheme.widgetPalette) okunuyor;
/// ornek tablo, gercek tabloyla ayni gorunur.

const double _radius = 14;
const double _rowHeight = 34;

BoxDecoration _frame(BuildContext context, Map<String, int> palette) =>
    BoxDecoration(
      color: Color(palette['rowEven']!),
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(color: Color(palette['line']!)),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

Widget _cell(
  String text, {
  required Color color,
  required TextAlign align,
  FontWeight weight = FontWeight.w400,
  double size = 12,
}) => Text(
  text,
  textAlign: align,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(fontSize: size, color: color, fontWeight: weight),
);

/// Kayit tablosu ornegi: tarih, nereden, kilo.
class OnboardingTablePreview extends StatelessWidget {
  const OnboardingTablePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final palette = AppTheme.widgetPalette(Theme.of(context));
    final tr = loc.locale.languageCode != 'en';

    final headers = tr
        ? ['tarih', 'nereden', 'kilo']
        : ['date', 'from', 'weight'];
    // Sayilar uygulamanin kendi bicimiyle: binlik ayracli.
    final rows = tr
        ? [
            ['12.03.2026', 'Konya', '18.500'],
            ['12.03.2026', 'Karaman', '22.000'],
            ['13.03.2026', 'Ankara', '16.750'],
          ]
        : [
            ['03/12/2026', 'Konya', '18,500'],
            ['03/12/2026', 'Karaman', '22,000'],
            ['03/13/2026', 'Ankara', '16,750'],
          ];
    // Ucuncu sutun sayisal: saga yaslanir, kalin yazilir.
    const flex = [36, 34, 30];

    return Container(
      decoration: _frame(context, palette),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: _rowHeight,
            color: Color(palette['header']!),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < headers.length; i++)
                  Expanded(
                    flex: flex[i],
                    child: _cell(
                      headers[i],
                      color: Color(palette['onHeader']!),
                      align: i == 2 ? TextAlign.right : TextAlign.left,
                      weight: FontWeight.w700,
                      size: 11,
                    ),
                  ),
              ],
            ),
          ),
          for (var r = 0; r < rows.length; r++)
            Container(
              height: _rowHeight,
              color: Color(palette[r.isEven ? 'rowEven' : 'rowOdd']!),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < rows[r].length; i++)
                    Expanded(
                      flex: flex[i],
                      child: _cell(
                        rows[r][i],
                        color: Color(palette['text']!),
                        align: i == 2 ? TextAlign.right : TextAlign.left,
                        weight: i == 2 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Cetele ornegi: solda isimler, ustte gunler, hucrelerde durum isaretleri.
class OnboardingTallyPreview extends StatelessWidget {
  const OnboardingTallyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final palette = AppTheme.widgetPalette(Theme.of(context));
    final tr = loc.locale.languageCode != 'en';
    final dark = Theme.of(context).brightness == Brightness.dark;

    const present = Color(0xFF16A34A);
    const absent = Color(0xFFDC2626);
    const excused = Color(0xFFF59E0B);

    final days = ['12', '13', '14', '15', '16'];
    // Son sutun bugun: cetele ekranindaki gibi kehribar zeminli.
    const todayIndex = 4;
    final names = tr
        ? ['Ahmet', 'Mehmet', 'Ayşe', 'Veli']
        : ['Alex', 'Taylor', 'Jordan', 'Sam'];
    final marks = [
      [present, present, present, excused, present],
      [present, absent, present, present, present],
      [present, present, excused, present, null],
      [absent, present, present, present, present],
    ];
    final codes = tr
        ? {present: 'V', absent: 'Y', excused: 'İ'}
        : {present: 'P', absent: 'A', excused: 'E'};

    Widget dayCell(Color? mark, bool today) {
      final fill = mark != null
          ? mark.withValues(alpha: dark ? 0.26 : 0.15)
          : (today ? Color(palette['todayCell']!) : null);
      return Expanded(
        child: Container(
          height: _rowHeight,
          alignment: Alignment.center,
          color: fill,
          child: mark == null
              ? null
              : _cell(
                  codes[mark]!,
                  color: AppTheme.readableInk(mark, dark: dark),
                  align: TextAlign.center,
                  weight: FontWeight.w700,
                ),
        ),
      );
    }

    return Container(
      decoration: _frame(context, palette),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: _rowHeight,
            color: Color(palette['header']!),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _cell(
                      tr ? 'kişi' : 'name',
                      color: Color(palette['onHeader']!),
                      align: TextAlign.left,
                      weight: FontWeight.w700,
                      size: 11,
                    ),
                  ),
                ),
                for (var d = 0; d < days.length; d++)
                  Expanded(
                    child: Container(
                      height: _rowHeight,
                      alignment: Alignment.center,
                      color: d == todayIndex
                          ? Color(palette['todayHeader']!)
                          : null,
                      child: _cell(
                        days[d],
                        color: Color(palette['onHeader']!),
                        align: TextAlign.center,
                        weight: FontWeight.w700,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var r = 0; r < names.length; r++)
            Container(
              color: Color(palette[r.isEven ? 'rowEven' : 'rowOdd']!),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _cell(
                        names[r],
                        color: Color(palette['text']!),
                        align: TextAlign.left,
                      ),
                    ),
                  ),
                  for (var d = 0; d < days.length; d++)
                    dayCell(marks[r][d], d == todayIndex),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Sesle kayit ornegi: ustte soylenen cumle, altta doldurdugu alanlar.
/// Ornek, ilk sayfadaki tablonun bir satiridir; sayi sozle soylenir, alana
/// rakam olarak duser.
class OnboardingVoicePreview extends StatelessWidget {
  const OnboardingVoicePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final palette = AppTheme.widgetPalette(Theme.of(context));
    final tr = loc.locale.languageCode != 'en';

    final spoken = tr
        ? '“nereden Konya, kilo on sekiz bin beş yüz”'
        : '“from Konya, weight eighteen thousand five hundred”';
    final fields = tr
        ? [
            ['nereden', 'Konya'],
            ['kilo', '18.500'],
          ]
        : [
            ['from', 'Konya'],
            ['weight', '18,500'],
          ];

    return Container(
      decoration: _frame(context, palette),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(palette['accent']!),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    size: 21,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    spoken,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(palette['text']!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final field in fields) ...[
            Container(height: 1, color: Color(palette['line']!)),
            SizedBox(
              height: _rowHeight,
              child: Row(
                children: [
                  Container(
                    width: 92,
                    color: Color(palette['header']!),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: _cell(
                      field[0],
                      color: Color(palette['onHeader']!),
                      align: TextAlign.left,
                      weight: FontWeight.w700,
                      size: 11,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _cell(
                        field[1],
                        color: Color(palette['text']!),
                        align: TextAlign.left,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
